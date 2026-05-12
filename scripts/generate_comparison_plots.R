#!/usr/bin/env Rscript
# generate_comparison_plots.R — Generate EM3 & EM7 combined plots for before/after comparison
#
# Usage: Rscript scripts/generate_comparison_plots.R <output_dir>

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
  library(lubridate)
})

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args) >= 1) args[1] else "comparison_output"

project_root <- getwd()
helpers_dir <- file.path(project_root, "src", "r", "helpers")

source(file.path(helpers_dir, "plotting_style.R"))
source(file.path(helpers_dir, "data_loading.R"))
source(file.path(helpers_dir, "triggers.R"))
source(file.path(helpers_dir, "macro_plots.R"))

cycle_path <- file.path(project_root, "cycle.toml")
toml_lines <- readLines(cycle_path, warn = FALSE)
data_lines <- grep("^data_xlsx\\s*=", toml_lines, value = TRUE)
if (length(data_lines) != 1) {
  stop("Expected exactly one data_xlsx entry in cycle.toml, found ", length(data_lines))
}
xlsx_path <- gsub('.*"([^"]+)".*', "\\1", data_lines[[1]])
if (!file.exists(xlsx_path)) {
  stop("Data.xlsx from cycle.toml not found at: ", xlsx_path)
}
message("Using Data.xlsx from cycle.toml: ", xlsx_path)
data <- load_all_data(xlsx_path)

data$Macro1 <- ensure_ept_percentage(data$Macro1)
data$Macro1 <- normalise_period(data$Macro1)
macro_triggers <- compute_macro_triggers(data$Macro1)

# Only generate EM3 and EM7
target_sites <- c("EM3", "EM7")
filtered <- data$Macro1[data$Macro1$Site %in% target_sites, ]

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
plot_macro_combined(filtered, macro_triggers, output_dir)

message("Done. Plots saved to: ", output_dir)
