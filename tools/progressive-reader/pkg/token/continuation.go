package token

import (
	"bufio"
	"crypto/sha256"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type ContinuationToken struct {
	File         string
	Offset       int
	Language     string
	TotalChunks  int
	Checksum     string
	CurrentChunk int
	HasMore      bool
}

func NewContinuationToken(file string, offset int, language string, totalChunks int, content []byte) *ContinuationToken {
	checksum := fmt.Sprintf("%x", sha256.Sum256(content))

	return &ContinuationToken{
		File:         file,
		Offset:       offset,
		Language:     language,
		TotalChunks:  totalChunks,
		Checksum:     checksum,
		CurrentChunk: offset - 1,
		HasMore:      offset < totalChunks,
	}
}

func (t *ContinuationToken) SaveToFile(path string) error {
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create token file: %w", err)
	}
	defer file.Close()

	writer := bufio.NewWriter(file)

	fmt.Fprintf(writer, "CONTINUE:file=%s\n", t.File)
	fmt.Fprintf(writer, "CONTINUE:offset=%d\n", t.Offset)
	fmt.Fprintf(writer, "CONTINUE:language=%s\n", t.Language)
	fmt.Fprintf(writer, "CONTINUE:totalChunks=%d\n", t.TotalChunks)
	fmt.Fprintf(writer, "CONTINUE:checksum=%s\n", t.Checksum)
	fmt.Fprintf(writer, "CONTINUE:currentChunk=%d\n", t.CurrentChunk)
	if t.HasMore {
		fmt.Fprintf(writer, "CONTINUE:hasMore=true\n")
	} else {
		fmt.Fprintf(writer, "CONTINUE:hasMore=false\n")
	}
	fmt.Fprintf(writer, "---\n")

	return writer.Flush()
}

func LoadFromFile(path string) (*ContinuationToken, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open token file: %w", err)
	}
	defer file.Close()

	token := &ContinuationToken{}
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()

		if line == "---" {
			break
		}

		if !strings.HasPrefix(line, "CONTINUE:") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimPrefix(parts[0], "CONTINUE:")
		value := parts[1]

		switch key {
		case "file":
			token.File = value
		case "offset":
			offset, err := strconv.Atoi(value)
			if err != nil {
				return nil, fmt.Errorf("invalid offset value: %w", err)
			}
			token.Offset = offset
		case "language":
			token.Language = value
		case "totalChunks":
			total, err := strconv.Atoi(value)
			if err != nil {
				return nil, fmt.Errorf("invalid totalChunks value: %w", err)
			}
			token.TotalChunks = total
		case "checksum":
			token.Checksum = value
		case "currentChunk":
			current, err := strconv.Atoi(value)
			if err != nil {
				return nil, fmt.Errorf("invalid currentChunk value: %w", err)
			}
			token.CurrentChunk = current
		case "hasMore":
			token.HasMore = value == "true"
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading token file: %w", err)
	}

	if token.File == "" {
		return nil, fmt.Errorf("invalid token file: missing file path")
	}

	return token, nil
}

func (t *ContinuationToken) ValidateChecksum(content []byte) error {
	currentChecksum := fmt.Sprintf("%x", sha256.Sum256(content))

	if currentChecksum != t.Checksum {
		return fmt.Errorf("file has been modified since token was created")
	}

	return nil
}
