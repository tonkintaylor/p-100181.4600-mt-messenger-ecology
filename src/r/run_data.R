#!/usr/bin/env Rscript
# run_data.R — raw spreadsheets -> MtMessengerEcologyData.xlsx (R data pipeline).

local({
  # Launcher "Show R warnings" option: emit warnings live instead of the
  # deferred end-of-run summary.
  if (nzchar(Sys.getenv("MTM_SHOW_WARNINGS"))) options(warn = 1)
  args <- commandArgs(trailingOnly = TRUE)
  validate_only <- "--validate" %in% args
  positional <- args[!startsWith(args, "--")]
  config_path <- if (length(positional) >= 1) positional[[1]] else "cycle.toml"

  # Resolve project root from script location so the script works regardless of cwd.
  file_args <- commandArgs(trailingOnly = FALSE)
  script_file <- sub("^--file=", "", file_args[grep("^--file=", file_args)])
  if (length(script_file) == 1 && nzchar(script_file)) {
    script_dir <- normalizePath(dirname(script_file), mustWork = FALSE)
    # src/r/run_data.R → project root is two levels up
    if (grepl("src[/\\\\]r$", script_dir)) {
      project_root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = FALSE)
    } else {
      project_root <- getwd()
    }
  } else {
    project_root <- getwd()
  }

  data_dir <- file.path(project_root, "src", "r", "data")
  src1 <- function(f) source(file.path(data_dir, f))

  renv_activate <- file.path(project_root, "renv", "activate.R")
  if (file.exists(renv_activate)) source(renv_activate)

  suppressPackageStartupMessages({
    library(readxl); library(openxlsx); library(dplyr)
    library(tidyr); library(lubridate)
  })
  for (m in c("schemas.R","domain_types.R","errors.R","validation.R","config.R",
              "writer.R","domains/clarity.R","domains/ldv.R","domains/rpd.R",
              "domains/sediment_ingest.R","domains/sediment.R",
              "domains/sediment_size.R","domains/sediment_summary.R",
              "domains/macro_ingest.R","domains/macro.R",
              "domains/macro_species.R","domains/macro_summary.R",
              "domains/fish.R","domains/fish_summary.R",
              "domains/rpd_summary.R","pipeline.R")) src1(m)

  cfg <- tryCatch(load_config(config_path), error = function(e) {
    message("Config error: ", conditionMessage(e)); quit(status = 1) })

  if (validate_only) {
    results <- list(
      process_macro_domain(cfg$macroinvertebrate_db),
      process_macro_species_domain(cfg$macroinvertebrate_db),
      process_sediment_domain(cfg$aquatic_monitoring_db),
      process_sediment_size_domain(cfg$aquatic_monitoring_db),
      process_clarity_domain(cfg$aquatic_monitoring_db),
      process_rpd_domain(cfg$aquatic_monitoring_db),
      process_ldv_domain(cfg$aquatic_monitoring_db),
      process_fish_domain(cfg$aquatic_monitoring_db),
      process_macro_summary_domain(cfg$macroinvertebrate_db),
      process_fish_summary_domain(cfg$aquatic_monitoring_db),
      process_sediment_summary_domain(cfg$aquatic_monitoring_db),
      process_rpd_summary_domain(cfg$aquatic_monitoring_db))
    errs <- do.call(c, lapply(results, function(r) r$errors))
    if (length(errs) > 0) for (e in errs) message("  ", format(e))
    ok <- all(vapply(results, function(r) r$ok(), logical(1)))
    if (!ok) { message("\nValidation failed."); quit(status = 1) }
    message("Validation passed."); quit(status = 0)
  }

  result <- run_pipeline(cfg)
  if (length(result$errors) > 0) for (e in result$errors) message("  ", format(e))
  if (!result$success) {
    n <- sum(vapply(result$errors, function(e) e$severity == "error", logical(1)))
    message(sprintf("\nPipeline failed: %d error(s) across domains", n))
    quit(status = 1)
  }
  message(sprintf("Wrote %s", cfg$data_xlsx))
})
