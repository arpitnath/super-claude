# Token Counter

Accurate token counting using Claude's actual tokenizer from Hugging Face.

**This is an OPTIONAL tool for testing/validating progressive-reader token savings.**

## Installation

```bash
# Install dependencies (one-time)
python3 tools/token-counter/token-counter.py --install
```

## Usage

### Count tokens in a file
```bash
python3 tools/token-counter/token-counter.py <file>
```

### Compare full file vs progressive-reader chunks
```bash
python3 tools/token-counter/token-counter.py <file> --compare-chunks
```

### Count tokens for specific chunks
```bash
# Validate actual savings from a session where you used chunks 19, 20, 21
python3 tools/token-counter/token-counter.py <file> 19,20,21
```

## Example Output

```
============================================================
TOKEN SAVINGS ANALYSIS
============================================================

File: src/unified_client.go
Size: 94.2 KB
Full file tokens: 24,156

Chunk Analysis:
------------------------------------------------------------
  Chunk 0:    2,891 tokens (88% savings vs full)
  Chunk 1:    2,756 tokens (89% savings vs full)
  Chunk 2:    2,934 tokens (88% savings vs full)
  Chunk 3:    2,812 tokens (88% savings vs full)
  Chunk 4:    2,901 tokens (88% savings vs full)
  ... and 5 more chunks

------------------------------------------------------------
SUMMARY
------------------------------------------------------------
Full file:            24,156 tokens
Avg chunk:             2,859 tokens
Savings/chunk:            88%

If you need 1 chunk:  88% savings
If you need 3 chunks: 65% savings
If you need 5 chunks: 41% savings
============================================================
```

## How It Works

Uses `Xenova/claude-tokenizer` from Hugging Face - this is the actual Claude tokenizer, not an estimation.

## Requirements

- Python 3.8+
- `transformers` package (installed via `--install` flag)
- `progressive-reader` (for chunk comparison)
