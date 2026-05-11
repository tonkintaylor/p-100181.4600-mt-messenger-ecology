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

xlsx_path <- file.path(project_root, "ref", "Data.xlsx")
data <- load_all_data(xlsx_path)

macro_triggers <- compute_macro_triggers(data$Macro1)

# Only generate EM3 and EM7
target_sites <- c("EM3", "EM7")
filtered <- data$Macro1[data$Macro1$Site %in% target_sites, ]

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
plot_macro_combined(filtered, macro_triggers, output_dir)

message("Done. Plots saved to: ", output_dir)
