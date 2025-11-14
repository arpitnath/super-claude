package main

// DetectCircularDependencies finds circular dependency cycles using Tarjan's algorithm
// Returns list of cycles where each cycle is a list of file paths
func DetectCircularDependencies(graph *DependencyGraph) [][]string {
	// Build adjacency list
	adj := make(map[string][]string)
	for path, node := range graph.Files {
		adj[path] = []string{}
		for _, imp := range node.Imports {
			// Only consider imports that exist in our graph
			if _, exists := graph.Files[imp.Path]; exists {
				adj[path] = append(adj[path], imp.Path)
			}
		}
	}

	// Tarjan's algorithm state
	index := 0
	stack := []string{}
	onStack := make(map[string]bool)
	indices := make(map[string]int)
	lowlinks := make(map[string]int)
	sccs := [][]string{}

	// Recursive strongconnect function
	var strongconnect func(string)
	strongconnect = func(v string) {
		indices[v] = index
		lowlinks[v] = index
		index++
		stack = append(stack, v)
		onStack[v] = true

		// Consider successors
		for _, w := range adj[v] {
			if _, visited := indices[w]; !visited {
				strongconnect(w)
				if lowlinks[w] < lowlinks[v] {
					lowlinks[v] = lowlinks[w]
				}
			} else if onStack[w] {
				if indices[w] < lowlinks[v] {
					lowlinks[v] = indices[w]
				}
			}
		}

		// If v is a root node, pop the stack and generate an SCC
		if lowlinks[v] == indices[v] {
			scc := []string{}
			for {
				w := stack[len(stack)-1]
				stack = stack[:len(stack)-1]
				onStack[w] = false
				scc = append(scc, w)
				if w == v {
					break
				}
			}
			// Only add if it's a cycle (more than 1 node)
			if len(scc) > 1 {
				sccs = append(sccs, scc)
			}
		}
	}

	// Run algorithm on all nodes
	for path := range graph.Files {
		if _, visited := indices[path]; !visited {
			strongconnect(path)
		}
	}

	return sccs
}

// DetectDeadCode finds files that are not imported by any other file
// These are potential entry points or unused code
func DetectDeadCode(graph *DependencyGraph) []string {
	deadCode := []string{}

	for path, node := range graph.Files {
		// If no one imports this file, it might be dead code
		// Exception: entry points like main.go, index.ts typically have no importers
		if len(node.ImportedBy) == 0 {
			deadCode = append(deadCode, path)
		}
	}

	return deadCode
}
