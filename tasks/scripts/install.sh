#!/bin/bash

# Install for users who need to run the pipeline.
#
# Usage:  ./tasks/install.ps1   (from repo root)

source ./tasks/shims/install_r           # Install R + R packages

# Create cycle.toml from template if it doesn't exist
if [ -f "cycle.example.toml" ] && [ ! -f "cycle.toml" ]; then
    echo ""
    echo "Creating cycle.toml from template..."
    cp cycle.example.toml cycle.toml
    echo "  Edit cycle.toml to set the correct input/output paths for your reporting cycle."
fi

# Smoke test
echo ""
echo "Verifying installation..."
if command -v Rscript &> /dev/null; then
    echo "  Rscript is available."
else
    echo "  Rscript not found — install R from https://cran.r-project.org/ and add it to PATH."
    exit 1
fi

echo ""
echo "============================================"
echo "  Installation complete!"
echo ""
echo "  Quick start:"
echo "    1. Edit cycle.toml with your input/output paths"
echo "    2. Run:  Rscript --vanilla src/r/run_data.R cycle.toml"
echo "    3. Run:  Rscript --vanilla src/r/run_pipeline.R cycle.toml"
echo "    4. Or:   Rscript --vanilla src/r/run_all.R cycle.toml"
echo "============================================"
