#!/usr/bin/env Rscript
# run_pipeline.R — data then figures (the all-R equivalent of `mgen all`).
local({
  args <- commandArgs(trailingOnly = TRUE)
  config_path <- if (length(args) >= 1) args[[1]] else "cycle.toml"

  # Resolve this script's location so sibling scripts can be found regardless
  # of the working directory.
  file_args <- commandArgs(trailingOnly = FALSE)
  script_file <- sub("^--file=", "", file_args[grep("^--file=", file_args)])
  if (length(script_file) == 1 && nzchar(script_file)) {
    script_dir <- normalizePath(dirname(script_file), mustWork = FALSE)
  } else {
    script_dir <- file.path(getwd(), "src", "r")
  }

  run_data_r  <- file.path(script_dir, "run_data.R")
  run_all_r   <- file.path(script_dir, "run_all.R")

  rc <- system2("Rscript", c("--vanilla", run_data_r, config_path))
  if (rc != 0) quit(status = rc)
  # Forward the same config to the figure stage so a custom cycle.toml is used
  # for both data and figures (run_all.R otherwise defaults to ./cycle.toml).
  config_abs <- normalizePath(config_path, mustWork = FALSE)
  rc2 <- system2("Rscript", c("--vanilla", run_all_r, paste0("--config=", config_abs)))
  quit(status = rc2)
})
