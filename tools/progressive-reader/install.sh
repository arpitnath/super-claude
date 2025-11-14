#!/bin/bash
set -eo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$HOME/.claude/bin"

echo "=========================================="
echo "Progressive Reader Installation"
echo "=========================================="
echo ""

cd "$TOOL_DIR"

echo "Detecting platform..."
OS=$(uname -s)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
    PLATFORM="darwin-arm64"
    echo "Platform: macOS Apple Silicon (ARM64)"
elif [[ "$OS" == "Darwin" && "$ARCH" == "x86_64" ]]; then
    PLATFORM="darwin-amd64"
    echo "Platform: macOS Intel (AMD64)"
elif [[ "$OS" == "Linux" && "$ARCH" == "x86_64" ]]; then
    PLATFORM="linux-amd64"
    echo "Platform: Linux (AMD64)"
elif [[ "$OS" == "MINGW"* || "$OS" == "MSYS"* ]]; then
    PLATFORM="windows-amd64"
    echo "Platform: Windows (AMD64)"
else
    echo "Error: Unsupported platform: $OS $ARCH"
    exit 1
fi

echo ""

BINARY="bin/progressive-reader-${PLATFORM}"

if [[ "$PLATFORM" == "windows-amd64" ]]; then
    BINARY="${BINARY}.exe"
fi

if [ ! -f "$BINARY" ]; then
    echo "Platform binary not found: $BINARY"
    echo ""
    echo "Building for current platform..."

    if ! command -v go &> /dev/null; then
        echo "Error: Go is not installed. Please install Go 1.21 or later."
        exit 1
    fi

    echo "Running: go build -o bin/progressive-reader cmd/main.go"
    go build -o bin/progressive-reader cmd/main.go

    if [ ! -f "bin/progressive-reader" ]; then
        echo "Error: Build failed"
        exit 1
    fi

    BINARY="bin/progressive-reader"
    echo "[SUCCESS] Build successful"
    echo ""
fi

echo "Installing progressive-reader..."
mkdir -p "$INSTALL_PATH"

if [[ "$BINARY" == *".exe" ]]; then
    cp "$BINARY" "$INSTALL_PATH/progressive-reader.exe"
    chmod +x "$INSTALL_PATH/progressive-reader.exe"
    echo "[SUCCESS] Installed: $INSTALL_PATH/progressive-reader.exe"
else
    cp "$BINARY" "$INSTALL_PATH/progressive-reader"
    chmod +x "$INSTALL_PATH/progressive-reader"
    echo "[SUCCESS] Installed: $INSTALL_PATH/progressive-reader"
fi

echo ""

echo "Testing installation..."
if "$INSTALL_PATH/progressive-reader" --version > /dev/null 2>&1; then
    VERSION=$("$INSTALL_PATH/progressive-reader" --version)
    echo "[SUCCESS] $VERSION"
else
    echo "[FAILED] Installation test failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Usage:"
echo "  progressive-reader --path <file>"
echo "  progressive-reader --help"
echo ""
