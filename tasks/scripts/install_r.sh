#!/bin/bash

echo "Ensuring R is installed..."

# Check default Windows install path first (Git Bash often lacks R on PATH)
r_bin=$(ls -d /c/Program\ Files/R/R-*/bin 2>/dev/null | tail -1)
if [ -n "$r_bin" ] && [ -x "$r_bin/Rscript.exe" ]; then
    export PATH="$PATH:$r_bin"
fi

if command -v Rscript &> /dev/null; then
    r_version=$(Rscript --version 2>&1 | head -1)
    echo "  R already installed: $r_version"
else
    echo "  R not found. Installing via winget..."
    if [ -n "$WINDIR" ]; then
        if command -v winget &> /dev/null; then
            winget install --id RProject.R --accept-source-agreements --accept-package-agreements --silent
            if [ $? -ne 0 ]; then
                echo "Error: Failed to install R via winget."
                echo "Please install R manually from https://cran.r-project.org/"
                exit 1
            fi
            r_bin=$(ls -d /c/Program\ Files/R/R-*/bin 2>/dev/null | tail -1)
            if [ -n "$r_bin" ]; then
                export PATH="$PATH:$r_bin"
            fi
        else
            echo "Error: winget not available. Please install R manually from https://cran.r-project.org/"
            exit 1
        fi
    else
        echo "Error: Non-Windows R installation not implemented. Please install R manually."
        exit 1
    fi
fi

echo "Ensuring R packages are installed..."
# Run from a script file — multi-line 'Rscript -e' segfaults through Git Bash on Windows.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Rscript --vanilla "$SCRIPT_DIR/install_r_packages.R"

if [ $? -ne 0 ]; then
    echo "Error: Failed to install R packages."
    exit 1
fi

echo "  R setup complete."
