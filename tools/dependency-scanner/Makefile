.PHONY: build build-all test clean install

# Build for current platform
build:
	@echo "Building dependency-scanner..."
	@go build -o bin/dependency-scanner .
	@echo "✅ Built: bin/dependency-scanner"

# Build for all platforms
build-all:
	@echo "Building for all platforms..."
	@mkdir -p bin

	# macOS Intel
	@GOOS=darwin GOARCH=amd64 go build -o bin/dependency-scanner-darwin-amd64 .
	@echo "✅ macOS Intel: bin/dependency-scanner-darwin-amd64"

	# macOS ARM (M1/M2/M3)
	@GOOS=darwin GOARCH=arm64 go build -o bin/dependency-scanner-darwin-arm64 .
	@echo "✅ macOS ARM: bin/dependency-scanner-darwin-arm64"

	# Linux AMD64
	@GOOS=linux GOARCH=amd64 go build -o bin/dependency-scanner-linux-amd64 .
	@echo "✅ Linux: bin/dependency-scanner-linux-amd64"

	# Windows
	@GOOS=windows GOARCH=amd64 go build -o bin/dependency-scanner-windows-amd64.exe .
	@echo "✅ Windows: bin/dependency-scanner-windows-amd64.exe"

	@echo ""
	@echo "All binaries built successfully!"

# Run tests
test:
	@echo "Running tests..."
	@go test ./... -v

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf bin/
	@echo "✅ Clean complete"

# Install to local bin
install:
	@echo "Installing to ~/.claude/bin..."
	@mkdir -p ~/.claude/bin
	@go build -o ~/.claude/bin/dependency-scanner .
	@echo "✅ Installed: ~/.claude/bin/dependency-scanner"

# Format code
fmt:
	@echo "Formatting code..."
	@go fmt ./...
	@echo "✅ Format complete"

# Run linter
lint:
	@echo "Running linter..."
	@golangci-lint run ./...
	@echo "✅ Lint complete"
