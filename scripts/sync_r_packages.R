#!/usr/bin/env Rscript
# sync_r_packages.R — synchronise this project's R package library to the exact
# versions frozen by a dated Posit Package Manager (PPM) snapshot.
#
# WHY THIS EXISTS
#   `renv::restore()` deadlocks on this project's openxlsx<->zip dependency pair
#   on Linux, and we don't want Docker. Instead we pin a single PPM *snapshot
#   date*: because every machine installs from the same dated repository, plain
#   `install.packages()` returns identical package versions everywhere — Windows,
#   macOS and Linux/CI — with no lockfile resolver and no containers.
#
# SINGLE SOURCE OF TRUTH — the DESCRIPTION file:
#   * Imports:               the list of direct packages to install
#   * Config/Repo/Snapshot:  the PPM snapshot date (YYYY-MM-DD) that pins versions
#   * Config/R/Version:      the required R major.minor (e.g. "4.5")
#
# To bump versions: change Config/Repo/Snapshot to a newer date and re-run.
# To add a package: add it to Imports: and re-run. Nothing else to edit.
#
# USAGE
#   Rscript scripts/sync_r_packages.R [options]
#     --dry-run            show the plan (repo, R check, packages) without installing
#     --force              reinstall every package to the snapshot version
#     --allow-r-mismatch   warn instead of stopping if the R version differs
#     --snapshot=DATE      override the snapshot date for this run only
#     --lib=PATH           install into PATH instead of the default library

## ---- pure helpers (also sourced by tests/r/test-sync-deps.R) ---------------

# Parse the DESCRIPTION file into the three things sync cares about.
read_project_meta <- function(description_path) {
  dcf <- read.dcf(description_path)
  field <- function(name) {
    if (name %in% colnames(dcf)) unname(trimws(dcf[1, name])) else NA_character_
  }
  imports <- field("Imports")
  pkgs <- if (is.na(imports)) {
    character(0)
  } else {
    parts <- trimws(strsplit(imports, ",")[[1]])
    parts <- sub("\\s*\\(.*\\)$", "", parts) # drop "(>= 1.0)" version constraints
    parts <- parts[nzchar(parts)]
    setdiff(parts, "R")
  }
  list(
    packages  = pkgs,
    snapshot  = field("Config/Repo/Snapshot"),
    r_version = field("Config/R/Version")
  )
}

# Read VERSION_CODENAME (e.g. "noble", "jammy") from an os-release file, or NA.
linux_codename <- function(os_release = "/etc/os-release") {
  if (!file.exists(os_release)) {
    return(NA_character_)
  }
  lines <- readLines(os_release, warn = FALSE)
  hit <- grep("^VERSION_CODENAME=", lines, value = TRUE)
  if (length(hit) == 0) {
    return(NA_character_)
  }
  gsub('^VERSION_CODENAME=|"', "", hit[1])
}

# Build the PPM repository URL for a snapshot date. On Linux we use the binary
# path for the detected distribution (much faster); Windows/macOS get binaries
# from the plain dated URL, and an unknown Linux distro falls back to source.
ppm_repo_url <- function(snapshot,
                         sysname = Sys.info()[["sysname"]],
                         os_release = "/etc/os-release") {
  base <- "https://packagemanager.posit.co/cran"
  if (identical(sysname, "Linux")) {
    codename <- linux_codename(os_release)
    if (!is.na(codename) && nzchar(codename)) {
      return(sprintf("%s/__linux__/%s/%s", base, codename, snapshot))
    }
  }
  sprintf("%s/%s", base, snapshot)
}

# Compare only major.minor (patch differences are fine for reproducibility).
r_version_matches <- function(required, current = getRversion()) {
  if (is.na(required) || !nzchar(required)) {
    return(TRUE)
  }
  mm <- function(v) paste(strsplit(as.character(v), "\\.")[[1]][1:2], collapse = ".")
  identical(mm(current), mm(required))
}

## ---- script-location + main ------------------------------------------------

script_dir <- function() {
  file_args <- commandArgs(trailingOnly = FALSE)
  hit <- sub("^--file=", "", file_args[grep("^--file=", file_args)])
  if (length(hit) == 1 && nzchar(hit)) {
    normalizePath(dirname(hit), mustWork = FALSE)
  } else {
    file.path(getwd(), "scripts")
  }
}

.sync_main <- function(argv = commandArgs(trailingOnly = TRUE)) {
  has <- function(flag) any(argv == flag)
  optval <- function(prefix) {
    hit <- grep(paste0("^", prefix), argv, value = TRUE)
    if (length(hit)) sub(prefix, "", hit[length(hit)]) else NA_character_
  }

  dry_run        <- has("--dry-run")
  force          <- has("--force")
  allow_mismatch <- has("--allow-r-mismatch")
  snapshot_over  <- optval("--snapshot=")
  lib_over       <- optval("--lib=")

  root <- normalizePath(file.path(script_dir(), ".."), mustWork = FALSE)
  desc_path <- file.path(root, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    stop("Cannot find DESCRIPTION at ", desc_path, call. = FALSE)
  }

  meta <- read_project_meta(desc_path)
  snapshot <- if (!is.na(snapshot_over)) snapshot_over else meta$snapshot
  if (is.na(snapshot) || !nzchar(snapshot)) {
    stop("No snapshot date found. Set 'Config/Repo/Snapshot: YYYY-MM-DD' in ",
         "DESCRIPTION or pass --snapshot=YYYY-MM-DD.", call. = FALSE)
  }
  if (length(meta$packages) == 0) {
    stop("No packages found in the Imports field of DESCRIPTION.", call. = FALSE)
  }

  # --- R version gate ---
  if (!r_version_matches(meta$r_version)) {
    msg <- sprintf(
      "R version mismatch: this project pins R %s but you are running R %s.",
      meta$r_version, getRversion()
    )
    if (allow_mismatch) {
      message("WARNING: ", msg, " (continuing because --allow-r-mismatch)")
    } else {
      stop(msg, "\n  Install R ", meta$r_version,
           ", or re-run with --allow-r-mismatch to proceed anyway.", call. = FALSE)
    }
  }

  # --- repository (dated PPM snapshot) ---
  repo <- ppm_repo_url(snapshot)
  options(repos = c(PPM = repo))
  # User-Agent so PPM serves binary packages (required for Linux binaries).
  options(HTTPUserAgent = sprintf(
    "R/%s R (%s)",
    getRversion(),
    paste(getRversion(), R.version$platform, R.version$arch, R.version$os)
  ))

  lib <- if (!is.na(lib_over)) lib_over else .libPaths()[1]

  cat("Project R dependency sync\n")
  cat("  DESCRIPTION : ", desc_path, "\n", sep = "")
  cat("  R version   : running ", as.character(getRversion()),
      " (pinned ", ifelse(is.na(meta$r_version), "any", meta$r_version), ")\n", sep = "")
  cat("  Snapshot    : ", snapshot, "\n", sep = "")
  cat("  Repository  : ", repo, "\n", sep = "")
  cat("  Library     : ", lib, "\n", sep = "")
  cat("  Packages    : ", length(meta$packages), " declared\n", sep = "")

  # --- decide what to install ---
  ap <- tryCatch(available.packages(repos = repo),
                 error = function(e) {
                   stop("Could not reach the PPM snapshot (", repo, "): ",
                        conditionMessage(e), call. = FALSE)
                 })
  installed <- rownames(installed.packages(lib.loc = lib))

  needs_install <- function(p) {
    if (force) return(TRUE)
    if (!(p %in% installed)) return(TRUE)
    if (!(p %in% rownames(ap))) return(FALSE) # not on CRAN snapshot; leave as-is
    have <- as.character(packageVersion(p, lib.loc = lib))
    want <- ap[p, "Version"]
    !identical(have, want)
  }

  to_install <- Filter(needs_install, meta$packages)

  if (length(to_install) == 0) {
    cat("\nAll declared packages already match the snapshot. Nothing to do.\n")
    return(invisible(0L))
  }

  cat("\n  To install/update: ", paste(to_install, collapse = ", "), "\n", sep = "")

  if (dry_run) {
    cat("\n--dry-run: no packages were installed.\n")
    return(invisible(0L))
  }

  install.packages(to_install, lib = lib, repos = repo)

  # Verify everything imported is now present.
  still_missing <- setdiff(meta$packages,
                           rownames(installed.packages(lib.loc = lib)))
  if (length(still_missing) > 0) {
    stop("These packages failed to install: ",
         paste(still_missing, collapse = ", "), call. = FALSE)
  }
  cat("\nDone. All declared packages are installed from the ", snapshot,
      " snapshot.\n", sep = "")
  invisible(0L)
}

# Run main only when executed via Rscript (not when sourced by tests).
if (sys.nframe() == 0L) {
  .sync_main()
}
