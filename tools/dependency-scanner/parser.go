package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	sitter "github.com/smacker/go-tree-sitter"
	"github.com/smacker/go-tree-sitter/golang"
	"github.com/smacker/go-tree-sitter/javascript"
	"github.com/smacker/go-tree-sitter/python"
	"github.com/smacker/go-tree-sitter/typescript/tsx"
	"github.com/smacker/go-tree-sitter/typescript/typescript"
)

// Parser handles parsing files with tree-sitter
type Parser struct {
	languages map[string]*sitter.Language
}

// NewParser creates a new parser with specified languages
func NewParser(languageNames []string) (*Parser, error) {
	p := &Parser{
		languages: make(map[string]*sitter.Language),
	}

	// Map language names to their grammar
	languageMap := map[string]*sitter.Language{
		"typescript": typescript.GetLanguage(),
		"tsx":        tsx.GetLanguage(),
		"javascript": javascript.GetLanguage(),
		"go":         golang.GetLanguage(),
		"python":     python.GetLanguage(),
	}

	// Load requested languages
	for _, lang := range languageNames {
		if grammar, ok := languageMap[lang]; ok {
			if grammar == nil {
				continue
			}
			p.languages[lang] = grammar
		}
	}

	return p, nil
}

// Parse parses a file and returns a FileNode
func (p *Parser) Parse(filePath string) (*FileNode, error) {
	// Determine language from extension
	lang := p.detectLanguage(filePath)
	if lang == "" {
		return nil, fmt.Errorf("unsupported file type: %s", filePath)
	}

	// Get grammar
	grammar, ok := p.languages[lang]
	if !ok {
		return nil, fmt.Errorf("grammar not loaded for: %s (available: %v)", lang, p.getLoadedLanguages())
	}

	if grammar == nil {
		return nil, fmt.Errorf("grammar is nil for language: %s", lang)
	}

	// Read file
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}

	// Create parser
	parser := sitter.NewParser()
	if parser == nil {
		return nil, fmt.Errorf("failed to create parser")
	}

	// Set language
	parser.SetLanguage(grammar)

	// Parse
	tree := parser.Parse(nil, content)
	if tree == nil {
		return nil, fmt.Errorf("failed to parse file")
	}
	defer tree.Close()

	// Create node
	node := &FileNode{
		Path:       filePath,
		Language:   lang,
		Imports:    []Import{},
		Exports:    []Export{},
		ImportedBy: []string{},
	}

	// Extract imports and exports using queries
	root := tree.RootNode()
	node.Imports = p.extractImports(root, content, lang)
	node.Exports = p.extractExports(root, content, lang)

	return node, nil
}

// getLoadedLanguages returns a list of loaded language names
func (p *Parser) getLoadedLanguages() []string {
	langs := []string{}
	for lang := range p.languages {
		langs = append(langs, lang)
	}
	return langs
}

// detectLanguage determines language from file extension
func (p *Parser) detectLanguage(filePath string) string {
	ext := filepath.Ext(filePath)
	switch ext {
	case ".tsx":
		// Check if tsx is loaded, otherwise fall back to typescript
		if _, ok := p.languages["tsx"]; ok {
			return "tsx"
		}
		return "typescript"
	case ".ts":
		return "typescript"
	case ".jsx":
		return "javascript"
	case ".js", ".mjs", ".cjs":
		return "javascript"
	case ".go":
		return "go"
	case ".py", ".pyi":
		return "python"
	default:
		return ""
	}
}

// extractImports extracts import statements from AST
func (p *Parser) extractImports(root *sitter.Node, content []byte, lang string) []Import {
	var imports []Import

	switch lang {
	case "typescript", "javascript", "tsx":
		imports = p.extractJSImports(root, content)
	case "go":
		imports = p.extractGoImports(root, content)
	case "python":
		imports = p.extractPythonImports(root, content)
	}

	return imports
}

// extractJSImports extracts JavaScript/TypeScript imports
func (p *Parser) extractJSImports(root *sitter.Node, content []byte) []Import {
	// Use manual traversal (more reliable than queries for multiple language variations)
	return p.traverseJSImports(root, content)
}

// traverseJSImports manually traverses AST for imports (fallback)
func (p *Parser) traverseJSImports(node *sitter.Node, content []byte) []Import {
	var imports []Import

	var traverse func(*sitter.Node)
	traverse = func(n *sitter.Node) {
		if n.Type() == "import_statement" {
			// Find string child (the import path)
			for i := 0; i < int(n.ChildCount()); i++ {
				child := n.Child(i)
				if child.Type() == "string" {
					pathText := content[child.StartByte():child.EndByte()]
					path := string(pathText)
					path = strings.Trim(path, "'\"")

					imports = append(imports, Import{
						Path:      path,
						Symbols:   []string{},
						IsDefault: false,
						Line:      int(n.StartPoint().Row) + 1,
					})
					break
				}
			}
		}

		// Recurse to children
		for i := 0; i < int(n.ChildCount()); i++ {
			traverse(n.Child(i))
		}
	}

	traverse(node)
	return imports
}

// extractGoImports extracts Go imports
func (p *Parser) extractGoImports(root *sitter.Node, content []byte) []Import {
	var imports []Import

	var traverse func(*sitter.Node)
	traverse = func(n *sitter.Node) {
		if n.Type() == "import_spec" {
			// Get the import path
			for i := 0; i < int(n.ChildCount()); i++ {
				child := n.Child(i)
				if child.Type() == "interpreted_string_literal" || child.Type() == "raw_string_literal" {
					pathText := content[child.StartByte():child.EndByte()]
					path := string(pathText)
					path = strings.Trim(path, "`\"")

					imports = append(imports, Import{
						Path:      path,
						Symbols:   []string{},
						IsDefault: false,
						Line:      int(n.StartPoint().Row) + 1,
					})
					break
				}
			}
		}

		// Recurse to children
		for i := 0; i < int(n.ChildCount()); i++ {
			traverse(n.Child(i))
		}
	}

	traverse(root)
	return imports
}

// extractPythonImports extracts Python imports
func (p *Parser) extractPythonImports(root *sitter.Node, content []byte) []Import {
	var imports []Import

	var traverse func(*sitter.Node)
	traverse = func(n *sitter.Node) {
		// Handle: import module
		if n.Type() == "import_statement" {
			for i := 0; i < int(n.ChildCount()); i++ {
				child := n.Child(i)
				if child.Type() == "dotted_name" || child.Type() == "aliased_import" {
					nameText := content[child.StartByte():child.EndByte()]
					path := string(nameText)

					imports = append(imports, Import{
						Path:      path,
						Symbols:   []string{},
						IsDefault: false,
						Line:      int(n.StartPoint().Row) + 1,
					})
				}
			}
		}

		// Handle: from module import ...
		if n.Type() == "import_from_statement" {
			var modulePath string
			for i := 0; i < int(n.ChildCount()); i++ {
				child := n.Child(i)
				if child.Type() == "dotted_name" || child.Type() == "relative_import" {
					moduleText := content[child.StartByte():child.EndByte()]
					modulePath = string(moduleText)
					break
				}
			}

			if modulePath != "" {
				imports = append(imports, Import{
					Path:      modulePath,
					Symbols:   []string{},
					IsDefault: false,
					Line:      int(n.StartPoint().Row) + 1,
				})
			}
		}

		// Recurse to children
		for i := 0; i < int(n.ChildCount()); i++ {
			traverse(n.Child(i))
		}
	}

	traverse(root)
	return imports
}

// extractExports extracts export statements from AST
func (p *Parser) extractExports(root *sitter.Node, content []byte, lang string) []Export {
	var exports []Export

	// Query patterns vary by language
	var queryStr string
	switch lang {
	case "typescript", "javascript":
		queryStr = `
			(export_statement) @export
			(function_declaration) @export
			(class_declaration) @export
		`
	case "go":
		queryStr = `
			(function_declaration) @export
			(type_declaration) @export
		`
	case "python":
		queryStr = `
			(function_definition) @export
			(class_definition) @export
		`
	default:
		return exports
	}

	// Create query
	query, err := sitter.NewQuery([]byte(queryStr), p.languages[lang])
	if err != nil {
		return exports
	}

	// Execute query
	cursor := sitter.NewQueryCursor()
	cursor.Exec(query, root)

	// Process matches
	for {
		match, ok := cursor.NextMatch()
		if !ok {
			break
		}

		for _, capture := range match.Captures {
			node := capture.Node
			line := int(node.StartPoint().Row) + 1

			// Extract name (simplified - would need more sophisticated extraction)
			exp := Export{
				Name:      "exported_symbol",
				Type:      "function",
				IsDefault: false,
				Line:      line,
			}
			exports = append(exports, exp)
		}
	}

	return exports
}
