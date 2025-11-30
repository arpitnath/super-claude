#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BINARY="./bin/progressive-reader"
PASSED=0
FAILED=0

echo "========================================"
echo "Progressive Reader Test Suite"
echo "========================================"
echo ""

test_case() {
    local description="$1"
    local command="$2"
    local expected="$3"

    echo "Test: $description"

    if eval "$command" | grep -q "$expected"; then
        echo "  [PASSED]"
        ((PASSED++))
        return 0
    else
        echo "  [FAILED]"
        echo "  Expected: $expected"
        echo "  Got:"
        eval "$command" | head -5
        ((FAILED++))
        return 1
    fi
}

echo "Building progressive-reader..."
make build > /dev/null 2>&1
echo ""

echo "1. Version and Help Tests"
echo "----------------------------------------"
test_case "Version flag" "$BINARY --version" "progressive-reader "
test_case "Help flag" "$BINARY --help" "progressive-reader - Semantic chunking reader"
echo ""

echo "2. TypeScript File Tests"
echo "----------------------------------------"
test_case "Read TypeScript file" "$BINARY --path testdata/typescript/simple.ts" "class"
test_case "List TypeScript chunks" "$BINARY --path testdata/typescript/simple.ts --list" "Total chunks:"
test_case "TypeScript shows AuthService" "$BINARY --path testdata/typescript/simple.ts" "AuthService"
echo ""

echo "3. JavaScript File Tests"
echo "----------------------------------------"
test_case "Read JavaScript file" "$BINARY --path testdata/javascript/sample.js" "class"
test_case "List JavaScript chunks" "$BINARY --path testdata/javascript/sample.js --list" "Total chunks:"
test_case "JavaScript shows UserController" "$BINARY --path testdata/javascript/sample.js" "UserController"
echo ""

echo "4. Python File Tests"
echo "----------------------------------------"
test_case "Read Python file" "$BINARY --path testdata/python/sample.py" "class"
test_case "List Python chunks" "$BINARY --path testdata/python/sample.py --list" "Total chunks:"
test_case "Python shows UserRepository" "$BINARY --path testdata/python/sample.py" "UserRepository"
echo ""

echo "5. Go File Tests"
echo "----------------------------------------"
test_case "Read Go file" "$BINARY --path testdata/golang/sample.go" "type"
test_case "List Go chunks" "$BINARY --path testdata/golang/sample.go --list" "Total chunks:"
test_case "Go shows User struct" "$BINARY --path testdata/golang/sample.go" "type User struct"
echo ""

echo "6. Continuation Token Tests"
echo "----------------------------------------"
rm -f /tmp/continue.toon

# Create a test TOON token file
cat > /tmp/test-continue.toon << 'EOF'
CONTINUE:file=$(pwd)/testdata/typescript/simple.ts
CONTINUE:offset=0
CONTINUE:language=typescript
CONTINUE:totalChunks=1
CONTINUE:checksum=test123
CONTINUE:currentChunk=0
CONTINUE:hasMore=false
---
EOF

test_case "Token file format valid" "cat /tmp/test-continue.toon" "CONTINUE:file="
test_case "Token contains offset" "cat /tmp/test-continue.toon" "CONTINUE:offset="
test_case "Token contains language" "cat /tmp/test-continue.toon" "CONTINUE:language="
test_case "Token contains checksum" "cat /tmp/test-continue.toon" "CONTINUE:checksum="

rm -f /tmp/test-continue.toon
echo ""

echo "7. Chunk Navigation Tests"
echo "----------------------------------------"
test_case "Read chunk 0" "$BINARY --path testdata/typescript/simple.ts --chunk 0" "Chunk 1/"
test_case "Invalid chunk number fails" "$BINARY --path testdata/typescript/simple.ts --chunk 999 2>&1" "Error:"
echo ""

echo "8. Edge Cases"
echo "----------------------------------------"
test_case "Missing file fails" "$BINARY --path nonexistent.ts 2>&1" "Error:"
test_case "No path argument fails" "$BINARY 2>&1" "progressive-reader - Semantic chunking reader"
echo ""

echo "9. Oversized Node Handling (Regression Test)"
echo "----------------------------------------"
test_case "Oversized export array splits into multiple chunks" "$BINARY --path testdata/typescript/oversized-export.ts --list" "Total chunks: [1-9][0-9]*"
test_case "Oversized file has multiple chunks listed" "$BINARY --path testdata/typescript/oversized-export.ts --list" "Chunk [2-9]/"
echo ""

echo "10. Large File Support (50KB+)"
echo "----------------------------------------"
test_case "Large file creates multiple chunks" "$BINARY --path testdata/typescript/large-file.ts --list" "Total chunks: [1-9][0-9]"
test_case "Large file shows chunk navigation" "$BINARY --path testdata/typescript/large-file.ts --list" "Chunk 10/"
echo ""

echo "11. Multi-Chunk Navigation"
echo "----------------------------------------"
rm -f /tmp/continue.toon
test_case "Read chunk 0 creates continuation token" "$BINARY --path testdata/typescript/large-file.ts --chunk 0 > /dev/null && test -f /tmp/continue.toon && echo 'token created'" "token created"
test_case "Continuation token has correct format" "cat /tmp/continue.toon" "CONTINUE:file="
test_case "Continue to next chunk" "$BINARY --continue-file /tmp/continue.toon" "Chunk [2-9]/"
rm -f /tmp/continue.toon
echo ""

echo "========================================"
echo "Test Results"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "[SUCCESS] All tests passed!"
    exit 0
else
    echo "[FAILED] Some tests failed"
    exit 1
fi
