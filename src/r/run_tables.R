#!/usr/bin/env Rscript
# run_tables.R — render the report-shaped tables from an already-produced
# MtMessengerEcologyData.xlsx. Second step after run_data.R. Writes one .xlsx
# per report table into a ReportTables/ subfolder (matching the existing
# per-table table convention: IndicatorSpecies/, NMDS/, ...).
#
# Usage:
#   Rscript --vanilla src/r/run_tables.R [cycle.toml] [out_dir]
# Defaults: config = cycle.toml; output = <tables_dir>/ReportTables/.

local({
  args <- commandArgs(trailingOnly = TRUE)
  positional <- args[!startsWith(args, "--")]
  config_path <- if (length(positional) >= 1) positional[[1]] else "cycle.toml"

  file_args <- commandArgs(trailingOnly = FALSE)
  script_file <- sub("^--file=", "", file_args[grep("^--file=", file_args)])
  script_dir <- if (length(script_file) == 1 && nzchar(script_file)) {
    normalizePath(dirname(script_file), mustWork = FALSE)
  } else getwd()
  project_root <- if (grepl("src[/\\\\]r$", script_dir)) {
    normalizePath(file.path(script_dir, "..", ".."), mustWork = FALSE)
  } else getwd()

  renv_activate <- file.path(project_root, "renv", "activate.R")
  if (file.exists(renv_activate)) source(renv_activate)
  suppressPackageStartupMessages({library(readxl); library(openxlsx)})

  source(file.path(project_root, "src", "r", "data", "config.R"))
  source(file.path(project_root, "src", "r", "reporting", "report_tables.R"))

  cfg <- tryCatch(load_config(config_path), error = function(e) {
    message("Config error: ", conditionMessage(e)); quit(status = 1) })

  if (is.null(cfg$data_xlsx) || !file.exists(cfg$data_xlsx)) {
    message("Data workbook not found: ", cfg$data_xlsx,
            "\nRun src/r/run_data.R first to build it.")
    quit(status = 1)
  }
  out_dir <- if (length(positional) >= 2) positional[[2]] else
    file.path(cfg$tables_dir, "ReportTables")

  message("Rendering report tables from ", cfg$data_xlsx)
  paths <- render_report_tables_xlsx(cfg$data_xlsx, out_dir)
  message(sprintf("Wrote %d report tables to %s", length(paths), out_dir))
})
