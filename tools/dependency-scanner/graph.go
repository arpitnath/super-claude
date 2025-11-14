package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

type DependencyGraph struct {
	Files       map[string]*FileNode `json:"Files"`
	Circular    [][]string           `json:"Circular"`
	DeadCode    []string             `json:"DeadCode"`
	LastUpdated time.Time            `json:"LastUpdated"`
}

type FileNode struct {
	Path       string   `json:"Path"`
	Language   string   `json:"Language"`
	Imports    []Import `json:"Imports"`
	Exports    []Export `json:"Exports"`
	ImportedBy []string `json:"ImportedBy"`
}

type Import struct {
	Path      string   `json:"Path"`
	Symbols   []string `json:"Symbols"`
	IsDefault bool     `json:"IsDefault"`
	Line      int      `json:"Line"`
}

type Export struct {
	Name      string `json:"Name"`
	Type      string `json:"Type"`
	IsDefault bool   `json:"IsDefault"`
	Line      int    `json:"Line"`
}

func NewDependencyGraph() *DependencyGraph {
	return &DependencyGraph{
		Files:       make(map[string]*FileNode),
		Circular:    [][]string{},
		DeadCode:    []string{},
		LastUpdated: time.Now(),
	}
}

func (g *DependencyGraph) SaveJSON(outputPath string) error {
	data, err := json.MarshalIndent(g, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(outputPath, data, 0644)
}

func (g *DependencyGraph) SaveTOON(outputPath string) error {
	var builder strings.Builder

	for filePath, node := range g.Files {
		builder.WriteString("FILE:")
		builder.WriteString(filePath)
		builder.WriteString("\n")

		builder.WriteString("LANG:")
		builder.WriteString(node.Language)
		builder.WriteString("\n")

		builder.WriteString("IMPORTS:")
		if len(node.Imports) > 0 {
			imports := make([]string, len(node.Imports))
			for i, imp := range node.Imports {
				imports[i] = fmt.Sprintf("%s:%d", imp.Path, imp.Line)
			}
			builder.WriteString(strings.Join(imports, ","))
		}
		builder.WriteString("\n")

		builder.WriteString("EXPORTS:")
		if len(node.Exports) > 0 {
			exports := make([]string, len(node.Exports))
			for i, exp := range node.Exports {
				exports[i] = fmt.Sprintf("%s:%s:%d", exp.Name, exp.Type, exp.Line)
			}
			builder.WriteString(strings.Join(exports, ","))
		}
		builder.WriteString("\n")

		builder.WriteString("IMPORTEDBY:")
		if len(node.ImportedBy) > 0 {
			builder.WriteString(strings.Join(node.ImportedBy, ","))
		}
		builder.WriteString("\n")

		builder.WriteString("---\n")
	}

	if len(g.Circular) > 0 {
		for _, cycle := range g.Circular {
			builder.WriteString("CIRCULAR:")
			builder.WriteString(strings.Join(cycle, ">"))
			builder.WriteString("\n")
		}
		builder.WriteString("---\n")
	}

	if len(g.DeadCode) > 0 {
		for _, deadFile := range g.DeadCode {
			builder.WriteString("DEADCODE:")
			builder.WriteString(deadFile)
			builder.WriteString("\n")
		}
		builder.WriteString("---\n")
	}

	builder.WriteString("META:lastUpdated=")
	builder.WriteString(g.LastUpdated.Format(time.RFC3339))
	builder.WriteString("\n")

	return os.WriteFile(outputPath, []byte(builder.String()), 0644)
}

func (g *DependencyGraph) PrintStats() {
	langCount := make(map[string]int)
	for _, node := range g.Files {
		langCount[node.Language]++
	}

	if len(langCount) > 0 {
		first := true
		for lang, count := range langCount {
			if !first {
				print(", ")
			}
			printf("%s (%d)", lang, count)
			first = false
		}
		println()
	}
}
