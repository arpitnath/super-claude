#!/usr/bin/env python3
"""
Token Counter - Accurate token counting using Claude's tokenizer

Uses the Xenova/claude-tokenizer from Hugging Face for accurate counts.
This is an OPTIONAL tool for testing/validating token savings.

Usage:
    python token-counter.py <file>                    # Count tokens in file
    python token-counter.py <file> --compare-chunks   # Compare full file vs chunks
    python token-counter.py <file> 19,20,21           # Count specific chunks
    python token-counter.py --install                 # Install dependencies

Requirements:
    pip install transformers
"""

import sys
import os
import subprocess
import argparse

# Suppress tokenizer parallelism warning
os.environ["TOKENIZERS_PARALLELISM"] = "false"

def install_dependencies():
    """Install required dependencies."""
    print("Installing dependencies...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "transformers", "-q"])
    print("Dependencies installed successfully!")
    print("\nYou can now run: python token-counter.py <file>")

def get_tokenizer():
    """Load the Claude tokenizer from Hugging Face."""
    try:
        from transformers import GPT2TokenizerFast
        # Suppress warnings
        import warnings
        warnings.filterwarnings("ignore")

        tokenizer = GPT2TokenizerFast.from_pretrained('Xenova/claude-tokenizer')
        return tokenizer
    except ImportError:
        print("Error: transformers not installed.")
        print("Run: python token-counter.py --install")
        sys.exit(1)
    except Exception as e:
        print(f"Error loading tokenizer: {e}")
        print("Run: python token-counter.py --install")
        sys.exit(1)

def count_tokens(text: str, tokenizer) -> int:
    """Count tokens in text using Claude tokenizer."""
    return len(tokenizer.encode(text))

def get_file_content(filepath: str) -> str:
    """Read file content."""
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        return f.read()

def format_number(n: int) -> str:
    """Format number with commas."""
    return f"{n:,}"

def compare_with_chunks(filepath: str, tokenizer):
    """Compare full file tokens vs progressive-reader chunks."""
    content = get_file_content(filepath)
    full_tokens = count_tokens(content, tokenizer)
    file_size = os.path.getsize(filepath)

    filename = os.path.basename(filepath)

    pr_path = os.path.expanduser("~/.claude/bin/progressive-reader")

    if not os.path.exists(pr_path):
        print(f"{filename}: {format_number(full_tokens)} tokens")
        print("(progressive-reader not installed)")
        return

    total_chunks = 0
    chunk_tokens = []

    # Get total chunks
    result = subprocess.run(
        [pr_path, "--list", "--path", filepath],
        capture_output=True,
        text=True
    )

    if "Total chunks:" in result.stdout:
        for line in result.stdout.split('\n'):
            if "Total chunks:" in line:
                total_chunks = int(line.split(":")[1].strip())
                break

    if total_chunks == 0:
        print(f"{filename}: {format_number(full_tokens)} tokens")
        return

    # Sample a few chunks to get average
    for i in range(min(total_chunks, 5)):
        result = subprocess.run(
            [pr_path, "--chunk", str(i), "--path", filepath],
            capture_output=True,
            text=True
        )
        tokens = count_tokens(result.stdout, tokenizer)
        chunk_tokens.append(tokens)

    avg_chunk = sum(chunk_tokens) / len(chunk_tokens) if chunk_tokens else 0
    savings_pct = (1 - avg_chunk / full_tokens) * 100

    print(f"{filename} ({file_size / 1024:.0f}KB)")
    print(f"  without progressive-reader: {format_number(full_tokens)} tokens (full file)")
    print(f"  with progressive-reader:    ~{int(avg_chunk)} tokens per chunk ({total_chunks} chunks)")
    print(f"  savings: {savings_pct:.0f}%")


def count_specific_chunks(filepath: str, chunk_nums: list, tokenizer):
    """Count tokens for specific chunks of a file."""
    content = get_file_content(filepath)
    full_tokens = count_tokens(content, tokenizer)
    file_size = os.path.getsize(filepath)
    filename = os.path.basename(filepath)

    pr_path = os.path.expanduser("~/.claude/bin/progressive-reader")
    if not os.path.exists(pr_path):
        print(f"Error: progressive-reader not found at {pr_path}")
        return

    chunk_tokens_total = 0
    chunk_details = []

    for chunk_num in chunk_nums:
        result = subprocess.run(
            [pr_path, "--chunk", str(chunk_num), "--path", filepath],
            capture_output=True,
            text=True
        )
        tokens = count_tokens(result.stdout, tokenizer)
        chunk_tokens_total += tokens
        chunk_details.append((chunk_num, tokens))

    savings = full_tokens - chunk_tokens_total
    savings_pct = (savings / full_tokens) * 100 if full_tokens > 0 else 0

    print(f"{filename} ({file_size / 1024:.0f}KB)")
    print(f"  Full file:     {format_number(full_tokens)} tokens")
    print(f"  Chunks used:   {', '.join(str(c) for c in chunk_nums)} ({len(chunk_nums)} chunks)")
    for chunk_num, tokens in chunk_details:
        print(f"    Chunk {chunk_num}: {format_number(tokens)} tokens")
    print(f"  Total chunks:  {format_number(chunk_tokens_total)} tokens")
    print(f"  Saved:         {format_number(savings)} tokens ({savings_pct:.0f}%)")


def main():
    parser = argparse.ArgumentParser(
        description="Count tokens using Claude's tokenizer"
    )
    parser.add_argument("file", nargs="?", help="File to count tokens")
    parser.add_argument("chunks", nargs="?", help="Comma-separated chunk numbers (e.g., 19,20,21)")
    parser.add_argument("--install", action="store_true", help="Install dependencies")
    parser.add_argument("--compare-chunks", action="store_true",
                        help="Compare full file vs progressive-reader chunks")

    args = parser.parse_args()

    if args.install:
        install_dependencies()
        return

    if not args.file:
        parser.print_help()
        return

    if not os.path.exists(args.file):
        print(f"Error: File not found: {args.file}")
        sys.exit(1)

    tokenizer = get_tokenizer()

    # Check if chunks were specified
    if args.chunks:
        try:
            chunk_nums = [int(c.strip()) for c in args.chunks.split(',')]
            count_specific_chunks(args.file, chunk_nums, tokenizer)
        except ValueError:
            print(f"Error: Invalid chunk numbers: {args.chunks}")
            print("Use comma-separated numbers, e.g., 19,20,21")
            sys.exit(1)
    elif args.compare_chunks:
        compare_with_chunks(args.file, tokenizer)
    else:
        content = get_file_content(args.file)
        tokens = count_tokens(content, tokenizer)
        file_size = os.path.getsize(args.file)
        print(f"File: {args.file}")
        print(f"Size: {file_size / 1024:.1f} KB")
        print(f"Tokens: {format_number(tokens)}")

if __name__ == "__main__":
    main()
