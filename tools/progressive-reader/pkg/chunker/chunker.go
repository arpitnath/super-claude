package chunker

import (
	"fmt"
	"strings"

	sitter "github.com/smacker/go-tree-sitter"
	"github.com/arpitnath/super-claude-kit/tools/progressive-reader/pkg/parser"
)

type Chunk struct {
	Content      string
	StartLine    int
	EndLine      int
	Type         string
	Name         string
	Context      string
	HasMore      bool
	TotalChunks  int
	CurrentChunk int
}

type Chunker struct {
	parser      *parser.Parser
	sourceCode  []byte
	sourceLines []string
	maxTokens   int
}

func NewChunker(filePath string, sourceCode []byte, maxTokens int) (*Chunker, error) {
	p, err := parser.NewParser(filePath)
	if err != nil {
		return nil, err
	}

	lines := strings.Split(string(sourceCode), "\n")

	return &Chunker{
		parser:      p,
		sourceCode:  sourceCode,
		sourceLines: lines,
		maxTokens:   maxTokens,
	}, nil
}

func (c *Chunker) ChunkFile() ([]Chunk, error) {
	tree, err := c.parser.Parse(c.sourceCode)
	if err != nil {
		return nil, fmt.Errorf("failed to parse file: %w", err)
	}
	defer tree.Close()

	lang := c.parser.GetLanguage()

	switch lang {
	case "typescript":
		return c.chunkTypeScript(tree)
	case "javascript":
		return c.chunkJavaScript(tree)
	case "python":
		return c.chunkPython(tree)
	case "go":
		return c.chunkGo(tree)
	default:
		return c.chunkFallback()
	}
}

func (c *Chunker) chunkTypeScript(tree *sitter.Tree) ([]Chunk, error) {
	root := tree.RootNode()
	var chunks []Chunk
	var currentChunk []string
	var currentStartLine int
	currentTokens := 0

	targetNodeTypes := map[string]bool{
		"class_declaration":       true,
		"function_declaration":    true,
		"method_definition":       true,
		"interface_declaration":   true,
		"type_alias_declaration":  true,
		"export_statement":        true,
		"lexical_declaration":     true,
	}

	var walkNodes func(node *sitter.Node)
	walkNodes = func(node *sitter.Node) {
		nodeType := node.Type()

		if targetNodeTypes[nodeType] || node == root {
			startLine := int(node.StartPoint().Row)
			endLine := int(node.EndPoint().Row)

			nodeContent := c.getLinesRange(startLine, endLine)
			nodeTokens := estimateTokens(nodeContent)

			if currentTokens+nodeTokens > c.maxTokens && len(currentChunk) > 0 {
				chunkContent := strings.Join(currentChunk, "\n")
				chunks = append(chunks, Chunk{
					Content:   chunkContent,
					StartLine: currentStartLine + 1,
					EndLine:   currentStartLine + len(currentChunk),
					Type:      extractNodeType(nodeType),
					Name:      extractNodeName(node, string(c.sourceCode)),
				})
				currentChunk = []string{}
				currentStartLine = startLine
				currentTokens = 0
			}

			if len(currentChunk) == 0 {
				currentStartLine = startLine
			}

			for i := startLine; i <= endLine && i < len(c.sourceLines); i++ {
				currentChunk = append(currentChunk, c.sourceLines[i])
			}
			currentTokens += nodeTokens

			return
		}

		for i := 0; i < int(node.ChildCount()); i++ {
			child := node.Child(i)
			if child != nil {
				walkNodes(child)
			}
		}
	}

	walkNodes(root)

	if len(currentChunk) > 0 {
		chunkContent := strings.Join(currentChunk, "\n")
		chunks = append(chunks, Chunk{
			Content:   chunkContent,
			StartLine: currentStartLine + 1,
			EndLine:   currentStartLine + len(currentChunk),
			Type:      "code",
			Name:      "",
		})
	}

	for i := range chunks {
		chunks[i].TotalChunks = len(chunks)
		chunks[i].CurrentChunk = i
		chunks[i].HasMore = i < len(chunks)-1
		chunks[i].Context = extractContext(chunks[i].Content)
	}

	return chunks, nil
}

func (c *Chunker) chunkJavaScript(tree *sitter.Tree) ([]Chunk, error) {
	root := tree.RootNode()
	var chunks []Chunk
	var currentChunk []string
	var currentStartLine int
	currentTokens := 0

	targetNodeTypes := map[string]bool{
		"class_declaration":      true,
		"function_declaration":   true,
		"method_definition":      true,
		"lexical_declaration":    true,
		"variable_declaration":   true,
		"export_statement":       true,
	}

	var walkNodes func(node *sitter.Node)
	walkNodes = func(node *sitter.Node) {
		nodeType := node.Type()

		if targetNodeTypes[nodeType] || node == root {
			startLine := int(node.StartPoint().Row)
			endLine := int(node.EndPoint().Row)

			nodeContent := c.getLinesRange(startLine, endLine)
			nodeTokens := estimateTokens(nodeContent)

			if currentTokens+nodeTokens > c.maxTokens && len(currentChunk) > 0 {
				chunkContent := strings.Join(currentChunk, "\n")
				chunks = append(chunks, Chunk{
					Content:   chunkContent,
					StartLine: currentStartLine + 1,
					EndLine:   currentStartLine + len(currentChunk),
					Type:      extractNodeType(nodeType),
					Name:      extractNodeName(node, string(c.sourceCode)),
				})
				currentChunk = []string{}
				currentStartLine = startLine
				currentTokens = 0
			}

			if len(currentChunk) == 0 {
				currentStartLine = startLine
			}

			for i := startLine; i <= endLine && i < len(c.sourceLines); i++ {
				currentChunk = append(currentChunk, c.sourceLines[i])
			}
			currentTokens += nodeTokens

			return
		}

		for i := 0; i < int(node.ChildCount()); i++ {
			child := node.Child(i)
			if child != nil {
				walkNodes(child)
			}
		}
	}

	walkNodes(root)

	if len(currentChunk) > 0 {
		chunkContent := strings.Join(currentChunk, "\n")
		chunks = append(chunks, Chunk{
			Content:   chunkContent,
			StartLine: currentStartLine + 1,
			EndLine:   currentStartLine + len(currentChunk),
			Type:      "code",
			Name:      "",
		})
	}

	for i := range chunks {
		chunks[i].TotalChunks = len(chunks)
		chunks[i].CurrentChunk = i
		chunks[i].HasMore = i < len(chunks)-1
		chunks[i].Context = extractContext(chunks[i].Content)
	}

	return chunks, nil
}

func (c *Chunker) chunkPython(tree *sitter.Tree) ([]Chunk, error) {
	root := tree.RootNode()
	var chunks []Chunk
	var currentChunk []string
	var currentStartLine int
	currentTokens := 0

	targetNodeTypes := map[string]bool{
		"class_definition":      true,
		"function_definition":   true,
		"decorated_definition":  true,
	}

	var walkNodes func(node *sitter.Node)
	walkNodes = func(node *sitter.Node) {
		nodeType := node.Type()

		if targetNodeTypes[nodeType] || node == root {
			startLine := int(node.StartPoint().Row)
			endLine := int(node.EndPoint().Row)

			nodeContent := c.getLinesRange(startLine, endLine)
			nodeTokens := estimateTokens(nodeContent)

			if currentTokens+nodeTokens > c.maxTokens && len(currentChunk) > 0 {
				chunkContent := strings.Join(currentChunk, "\n")
				chunks = append(chunks, Chunk{
					Content:   chunkContent,
					StartLine: currentStartLine + 1,
					EndLine:   currentStartLine + len(currentChunk),
					Type:      extractPythonNodeType(nodeType),
					Name:      extractNodeName(node, string(c.sourceCode)),
				})
				currentChunk = []string{}
				currentStartLine = startLine
				currentTokens = 0
			}

			if len(currentChunk) == 0 {
				currentStartLine = startLine
			}

			for i := startLine; i <= endLine && i < len(c.sourceLines); i++ {
				currentChunk = append(currentChunk, c.sourceLines[i])
			}
			currentTokens += nodeTokens

			return
		}

		for i := 0; i < int(node.ChildCount()); i++ {
			child := node.Child(i)
			if child != nil {
				walkNodes(child)
			}
		}
	}

	walkNodes(root)

	if len(currentChunk) > 0 {
		chunkContent := strings.Join(currentChunk, "\n")
		chunks = append(chunks, Chunk{
			Content:   chunkContent,
			StartLine: currentStartLine + 1,
			EndLine:   currentStartLine + len(currentChunk),
			Type:      "code",
			Name:      "",
		})
	}

	for i := range chunks {
		chunks[i].TotalChunks = len(chunks)
		chunks[i].CurrentChunk = i
		chunks[i].HasMore = i < len(chunks)-1
		chunks[i].Context = extractContext(chunks[i].Content)
	}

	return chunks, nil
}

func (c *Chunker) chunkGo(tree *sitter.Tree) ([]Chunk, error) {
	root := tree.RootNode()
	var chunks []Chunk
	var currentChunk []string
	var currentStartLine int
	currentTokens := 0

	targetNodeTypes := map[string]bool{
		"function_declaration": true,
		"method_declaration":   true,
		"type_declaration":     true,
		"const_declaration":    true,
		"var_declaration":      true,
	}

	var walkNodes func(node *sitter.Node)
	walkNodes = func(node *sitter.Node) {
		nodeType := node.Type()

		if targetNodeTypes[nodeType] || node == root {
			startLine := int(node.StartPoint().Row)
			endLine := int(node.EndPoint().Row)

			nodeContent := c.getLinesRange(startLine, endLine)
			nodeTokens := estimateTokens(nodeContent)

			if currentTokens+nodeTokens > c.maxTokens && len(currentChunk) > 0 {
				chunkContent := strings.Join(currentChunk, "\n")
				chunks = append(chunks, Chunk{
					Content:   chunkContent,
					StartLine: currentStartLine + 1,
					EndLine:   currentStartLine + len(currentChunk),
					Type:      extractGoNodeType(nodeType),
					Name:      extractNodeName(node, string(c.sourceCode)),
				})
				currentChunk = []string{}
				currentStartLine = startLine
				currentTokens = 0
			}

			if len(currentChunk) == 0 {
				currentStartLine = startLine
			}

			for i := startLine; i <= endLine && i < len(c.sourceLines); i++ {
				currentChunk = append(currentChunk, c.sourceLines[i])
			}
			currentTokens += nodeTokens

			return
		}

		for i := 0; i < int(node.ChildCount()); i++ {
			child := node.Child(i)
			if child != nil {
				walkNodes(child)
			}
		}
	}

	walkNodes(root)

	if len(currentChunk) > 0 {
		chunkContent := strings.Join(currentChunk, "\n")
		chunks = append(chunks, Chunk{
			Content:   chunkContent,
			StartLine: currentStartLine + 1,
			EndLine:   currentStartLine + len(currentChunk),
			Type:      "code",
			Name:      "",
		})
	}

	for i := range chunks {
		chunks[i].TotalChunks = len(chunks)
		chunks[i].CurrentChunk = i
		chunks[i].HasMore = i < len(chunks)-1
		chunks[i].Context = extractContext(chunks[i].Content)
	}

	return chunks, nil
}

func (c *Chunker) chunkFallback() ([]Chunk, error) {
	var chunks []Chunk
	chunkSize := c.maxTokens * 4

	for i := 0; i < len(c.sourceLines); i += chunkSize {
		end := i + chunkSize
		if end > len(c.sourceLines) {
			end = len(c.sourceLines)
		}

		content := strings.Join(c.sourceLines[i:end], "\n")
		chunks = append(chunks, Chunk{
			Content:   content,
			StartLine: i + 1,
			EndLine:   end,
			Type:      "text",
			Name:      "",
		})
	}

	for i := range chunks {
		chunks[i].TotalChunks = len(chunks)
		chunks[i].CurrentChunk = i
		chunks[i].HasMore = i < len(chunks)-1
		chunks[i].Context = extractContext(chunks[i].Content)
	}

	return chunks, nil
}

func (c *Chunker) getLinesRange(start, end int) string {
	if start < 0 {
		start = 0
	}
	if end >= len(c.sourceLines) {
		end = len(c.sourceLines) - 1
	}

	var lines []string
	for i := start; i <= end; i++ {
		lines = append(lines, c.sourceLines[i])
	}
	return strings.Join(lines, "\n")
}

func estimateTokens(text string) int {
	return len(text) / 4
}

func extractNodeType(nodeType string) string {
	switch nodeType {
	case "class_declaration":
		return "class"
	case "function_declaration":
		return "function"
	case "method_definition":
		return "method"
	case "interface_declaration":
		return "interface"
	case "type_alias_declaration":
		return "type"
	default:
		return "code"
	}
}

func extractNodeName(node *sitter.Node, source string) string {
	for i := 0; i < int(node.ChildCount()); i++ {
		child := node.Child(i)
		if child.Type() == "identifier" || child.Type() == "type_identifier" {
			start := child.StartByte()
			end := child.EndByte()
			if int(end) <= len(source) {
				return source[start:end]
			}
		}
	}
	return ""
}

func extractPythonNodeType(nodeType string) string {
	switch nodeType {
	case "class_definition":
		return "class"
	case "function_definition":
		return "function"
	case "decorated_definition":
		return "decorated"
	default:
		return "code"
	}
}

func extractGoNodeType(nodeType string) string {
	switch nodeType {
	case "function_declaration":
		return "function"
	case "method_declaration":
		return "method"
	case "type_declaration":
		return "type"
	case "const_declaration":
		return "const"
	case "var_declaration":
		return "var"
	default:
		return "code"
	}
}

func extractContext(content string) string {
	lines := strings.Split(content, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "/*") || strings.HasPrefix(trimmed, "*") {
			comment := strings.TrimPrefix(trimmed, "//")
			comment = strings.TrimPrefix(comment, "/*")
			comment = strings.TrimPrefix(comment, "*")
			comment = strings.TrimSpace(comment)
			if len(comment) > 60 {
				return comment[:60]
			}
			if len(comment) > 0 {
				return comment
			}
		}
	}

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if len(trimmed) > 0 && !strings.HasPrefix(trimmed, "import") {
			if len(trimmed) > 60 {
				return trimmed[:60]
			}
			return trimmed
		}
	}

	return "Code chunk"
}
