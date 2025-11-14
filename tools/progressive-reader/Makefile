.PHONY: build build-all install test clean

BINARY_NAME=progressive-reader
INSTALL_PATH=$(HOME)/.claude/bin

build:
	go build -o bin/$(BINARY_NAME) cmd/main.go

build-all:
	GOOS=darwin GOARCH=amd64 go build -o bin/$(BINARY_NAME)-darwin-amd64 cmd/main.go
	GOOS=darwin GOARCH=arm64 go build -o bin/$(BINARY_NAME)-darwin-arm64 cmd/main.go
	GOOS=linux GOARCH=amd64 go build -o bin/$(BINARY_NAME)-linux-amd64 cmd/main.go
	GOOS=windows GOARCH=amd64 go build -o bin/$(BINARY_NAME)-windows-amd64.exe cmd/main.go

install: build
	mkdir -p $(INSTALL_PATH)
	cp bin/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	chmod +x $(INSTALL_PATH)/$(BINARY_NAME)

test:
	go test ./... -v -cover

clean:
	rm -rf bin/
