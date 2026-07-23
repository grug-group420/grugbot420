#!/bin/bash
echo "=== File Counts by Type ==="
echo "Julia files: $(ls -1 *.jl 2>/dev/null | wc -l)"
echo "Python files: $(ls -1 *.py 2>/dev/null | wc -l)"
echo "Markdown docs: $(ls -1 *.md 2>/dev/null | wc -l)"
echo ""
echo "=== Top 10 Largest Files ==="
ls -lhS *.{jl,py,md,toml} 2>/dev/null | head -10
echo ""
echo "=== Key Directories ==="
find . -maxdepth 2 -type d | grep -v "\.git" | head -20
echo ""
echo "=== Potential Entry Points ==="
ls -la boot.jl talk_to_grug.jl run_*test.jl 2>/dev/null
