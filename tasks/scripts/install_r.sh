#!/bin/bash

echo "Ensuring R is installed..."

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
            # Refresh PATH to pick up new R installation
            export PATH="$PATH:/c/Program Files/R/R-*/bin"
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
Rscript -e "
required <- c('readxl', 'dplyr', 'tidyr', 'ggplot2', 'vegan', 'indicspecies',
              'ggrepel', 'zoo', 'patchwork', 'openxlsx', 'lubridate')
missing <- required[!required %in% installed.packages()[, 'Package']]
if (length(missing) > 0) {
  cat('  Installing:', paste(missing, collapse=', '), '\n')
  install.packages(missing, repos='https://cloud.r-project.org/', quiet=TRUE)
} else {
  cat('  All R packages already installed.\n')
}
"

if [ $? -ne 0 ]; then
    echo "Error: Failed to install R packages."
    exit 1
fi

echo "  R setup complete."
