package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Scanner orchestrates the dependency scanning process
type Scanner struct {
	rootPath   string
	parser     *Parser
	graph      *DependencyGraph
	verbose    bool
}

// NewScanner creates a new scanner instance
func NewScanner(rootPath string, verbose bool) (*Scanner, error) {
	// Load detected languages from .claude/.languages
	languages, err := loadDetectedLanguages()
	if err != nil {
		return nil, fmt.Errorf("failed to load languages: %w", err)
	}

	if verbose {
		printf("Loaded languages: %v\n", languages)
	}

	// Create parser with detected languages
	parser, err := NewParser(languages)
	if err != nil {
		return nil, fmt.Errorf("failed to create parser: %w", err)
	}

	return &Scanner{
		rootPath: rootPath,
		parser:   parser,
		graph:    NewDependencyGraph(),
		verbose:  verbose,
	}, nil
}

// loadDetectedLanguages reads the .claude/.languages file
func loadDetectedLanguages() ([]string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	langFile := filepath.Join(homeDir, ".claude", ".languages")

	// If file doesn't exist, use defaults
	if _, err := os.Stat(langFile); os.IsNotExist(err) {
		return []string{"typescript", "javascript", "go", "python"}, nil
	}

	content, err := os.ReadFile(langFile)
	if err != nil {
		return nil, err
	}

	// Parse languages (one per line)
	lines := strings.Split(string(content), "\n")
	var languages []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "#") {
			languages = append(languages, line)
		}
	}

	if len(languages) == 0 {
		return []string{"typescript", "javascript", "go", "python"}, nil
	}

	return languages, nil
}

// Scan walks the directory tree and builds the dependency graph
func (s *Scanner) Scan() error {
	if s.verbose {
		printf("Scanning directory: %s\n", s.rootPath)
	}

	// Walk directory tree
	err := filepath.Walk(s.rootPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip directories
		if info.IsDir() {
			// Skip common directories
			name := info.Name()
			if name == "node_modules" || name == ".git" || name == "vendor" ||
			   name == "dist" || name == "build" || name == ".next" {
				return filepath.SkipDir
			}
			return nil
		}

		// Check if file is supported
		if s.isSupportedFile(path) {
			if s.verbose {
				printf("Parsing: %s\n", path)
			}

			node, err := s.parser.Parse(path)
			if err != nil {
				if s.verbose {
					printf("Warning: Failed to parse %s: %v\n", path, err)
				}
				return nil // Continue on parse errors
			}

			s.graph.Files[path] = node
		}

		return nil
	})

	if err != nil {
		return err
	}

	// Build reverse dependencies
	s.buildReverseImports()

	// Detect circular dependencies
	s.graph.Circular = DetectCircularDependencies(s.graph)

	// Detect dead code
	s.graph.DeadCode = DetectDeadCode(s.graph)

	if s.verbose {
		printf("Scan complete: %d files processed\n", len(s.graph.Files))
	}

	return nil
}

// isSupportedFile checks if a file should be parsed
func (s *Scanner) isSupportedFile(path string) bool {
	ext := filepath.Ext(path)
	supportedExts := map[string]bool{
		".ts":   true,
		".tsx":  true,
		".js":   true,
		".jsx":  true,
		".mjs":  true,
		".cjs":  true,
		".go":   true,
		".py":   true,
		".pyi":  true,
	}
	return supportedExts[ext]
}

// buildReverseImports populates the ImportedBy field for each file
func (s *Scanner) buildReverseImports() {
	for filePath, node := range s.graph.Files {
		for i, imp := range node.Imports {
			resolvedPath := s.resolveImport(filePath, imp.Path)
			if resolvedPath == "" {
				continue
			}

			node.Imports[i].Path = resolvedPath

			if importedNode, exists := s.graph.Files[resolvedPath]; exists {
				importedNode.ImportedBy = append(importedNode.ImportedBy, filePath)
			}
		}
	}
}

// resolveImport resolves an import path to an absolute file path
func (s *Scanner) resolveImport(fromFile, importPath string) string {
	// Skip external packages
	if !strings.HasPrefix(importPath, ".") && !strings.HasPrefix(importPath, "/") {
		return ""
	}

	fromDir := filepath.Dir(fromFile)

	// Handle relative imports
	resolved := filepath.Join(fromDir, importPath)

	// Try different extensions
	extensions := []string{"", ".ts", ".tsx", ".js", ".jsx", ".go", ".py"}
	for _, ext := range extensions {
		testPath := resolved + ext
		if _, err := os.Stat(testPath); err == nil {
			return testPath
		}
	}

	// Try index files
	for _, indexFile := range []string{"index.ts", "index.tsx", "index.js", "index.jsx"} {
		testPath := filepath.Join(resolved, indexFile)
		if _, err := os.Stat(testPath); err == nil {
			return testPath
		}
	}

	return ""
}

// GetGraph returns the built dependency graph
func (s *Scanner) GetGraph() *DependencyGraph {
	return s.graph
}
