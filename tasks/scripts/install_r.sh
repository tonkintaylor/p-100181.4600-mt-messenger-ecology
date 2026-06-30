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

echo "Restoring R packages from renv.lock..."
# Hard-gate the R version (renv::restore only WARNS on a mismatch), bootstrap
# renv if absent, restore, then VERIFY every declared import is installed -
# renv::restore can exit 0 on a partial restore, so a bare $? check is not enough.
Rscript -e '
want <- tryCatch(trimws(read.dcf("DESCRIPTION")[1, "Config/R/Version"]), error = function(e) NA)
cur  <- sub("^(\\d+\\.\\d+).*", "\\1", as.character(getRversion()))
if (!is.na(want) && !identical(cur, want))
  stop(sprintf("This project requires R %s but you are running R %s. Install R %s and re-run.", want, getRversion(), want), call. = FALSE)
if (!requireNamespace("renv", quietly = TRUE))
  install.packages("renv", repos = "https://packagemanager.posit.co/cran/latest")
if (!requireNamespace("renv", quietly = TRUE)) stop("Could not install renv.", call. = FALSE)
renv::restore(prompt = FALSE)
imp  <- tryCatch(read.dcf("DESCRIPTION")[1, "Imports"], error = function(e) "")
pkgs <- setdiff(trimws(sub("\\s*\\(.*\\)$", "", strsplit(imp, ",")[[1]])), c("", "R"))
miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop(sprintf("Restore incomplete; missing: %s", paste(miss, collapse = ", ")), call. = FALSE)
cat(sprintf("renv restore complete: %d declared packages available.\n", length(pkgs)))
'

if [ $? -ne 0 ]; then
    echo "Error: Failed to restore R packages from renv.lock."
    echo "Try running: Rscript -e \"renv::restore()\""
    exit 1
fi

echo "  R setup complete."
