#!/usr/bin/env Rscript
# restore_renv.R - restore the renv.lock library and verify the result.
#
# Run from the repo root: it reads ./DESCRIPTION and ./renv.lock. Invoke as a
# FILE (`Rscript scripts/restore_renv.R`), not via `Rscript -e "..."` through
# Git Bash: passing a multi-line -e program through MSYS to the native
# Rscript.exe corrupts the argument and crashes R.

# Gate the R version up front: renv::restore() only WARNS on a mismatch, but the
# locked binaries are built for one R major.minor.
want <- tryCatch(trimws(read.dcf("DESCRIPTION")[1, "Config/R/Version"]),
                 error = function(e) NA_character_)
cur <- sub("^(\\d+\\.\\d+).*", "\\1", as.character(getRversion()))
# Compare by value (!=), not identical(): read.dcf() can mark the string with a
# different encoding than getRversion()'s, so identical() returns FALSE on equal
# text ("4.5" vs "4.5").
if (!is.na(want) && cur != want) {
  stop(sprintf("This project requires R %s but you are running R %s. Install R %s and re-run.",
               want, getRversion(), want), call. = FALSE)
}

# Bootstrap renv if the project library doesn't have it yet, then restore.
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://packagemanager.posit.co/cran/latest")
}
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Could not install renv.", call. = FALSE)
}

renv::restore(prompt = FALSE)

# Verify completeness WITHOUT loading the packages: renv::restore can return
# normally on a partial restore, but loading many compiled packages in one
# session can crash R. installed.packages() just scans the library on disk.
imp  <- tryCatch(read.dcf("DESCRIPTION")[1, "Imports"], error = function(e) "")
pkgs <- setdiff(trimws(sub("\\s*\\(.*\\)$", "", strsplit(imp, ",")[[1]])), c("", "R"))
miss <- setdiff(pkgs, rownames(installed.packages()))
if (length(miss)) {
  stop(sprintf("Restore incomplete; missing: %s", paste(miss, collapse = ", ")), call. = FALSE)
}
cat(sprintf("renv restore complete: %d declared packages installed.\n", length(pkgs)))
