#!/bin/bash

# Lightweight install for end users who only need to run the pipeline.
# Skips developer tooling (linters, hooks, VS Code config).
#
# Usage:  ./tasks/install.ps1   (from repo root)

source ./tasks/shims/install_backend     # Install/update uv
source ./tasks/shims/install_venv        # Create .venv
source ./tasks/shims/activate_venv       # Activate .venv

echo "Installing pipeline dependencies (production only)..."
output=$(uv sync --no-group dev --no-group doc 2>&1)
if [ $? -ne 0 ]; then
    echo "$output"
    echo "Error: Failed to install dependencies."
    exit 1
fi

source ./tasks/shims/install_r           # Install R + R packages

# Create cycle.toml from template if it doesn't exist
if [ -f "cycle.example.toml" ] && [ ! -f "cycle.toml" ]; then
    echo ""
    echo "Creating cycle.toml from template..."
    cp cycle.example.toml cycle.toml
    echo "  ⚠️  Edit cycle.toml to set the correct input/output paths for your reporting cycle."
fi

# Smoke test
echo ""
echo "Verifying installation..."
if uv run mgen --help > /dev/null 2>&1; then
    echo "  ✅ mgen is installed and working."
else
    echo "  ❌ mgen failed to run. Check the errors above."
    exit 1
fi

if command -v Rscript &> /dev/null; then
    echo "  ✅ Rscript is available."
else
    echo "  ⚠️  Rscript not found — 'mgen figures' will not work until R is installed."
fi

echo ""
echo "============================================"
echo "  Installation complete!"
echo ""
echo "  Quick start:"
echo "    1. Edit cycle.toml with your input/output paths"
echo "    2. Run:  mgen data       (process spreadsheets)"
echo "    3. Run:  mgen figures    (generate R figures)"
echo "    4. Or:   mgen all        (both steps)"
echo "============================================"
