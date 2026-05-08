#!/usr/bin/env Rscript
# run_all.R — Mt Messenger Ecology Figure Generation Pipeline
#
# Usage:
#   Rscript src/r/run_all.R [path/to/Data.xlsx] [figures_dir] [tables_dir]
#
# Defaults:
#   Data.xlsx:   ref/Data.xlsx
#   figures_dir: src/r/outputs/
#   tables_dir:  same as figures_dir

# --- Setup ---
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(vegan)
  library(indicspecies)
  library(ggrepel)
  library(zoo)
  library(patchwork)
  library(openxlsx)
  library(lubridate)
})

# Determine project root (assuming script is at src/r/run_all.R)
script_dir <- if (interactive()) {
  "src/r"
} else {
  dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))])
}
# Handle both running from project root and from src/r/
if (grepl("src[/\\\\]r$", script_dir)) {
  project_root <- normalizePath(file.path(script_dir, "..", ".."), mustWork = FALSE)
} else {
  project_root <- getwd()
}

# Source helper modules
helpers_dir <- file.path(project_root, "src", "r", "helpers")
source(file.path(helpers_dir, "data_loading.R"))
source(file.path(helpers_dir, "plotting_style.R"))
source(file.path(helpers_dir, "triggers.R"))
source(file.path(helpers_dir, "sediment_plots.R"))
source(file.path(helpers_dir, "macro_plots.R"))
source(file.path(helpers_dir, "nmds_plots.R"))
source(file.path(helpers_dir, "clarity_plots.R"))

# --- Parse arguments ---
args <- commandArgs(trailingOnly = TRUE)
xlsx_path <- if (length(args) >= 1) args[1] else file.path(project_root, "ref", "Data.xlsx")
output_dir <- if (length(args) >= 2) args[2] else file.path(project_root, "src", "r", "outputs")
tables_dir <- if (length(args) >= 3) args[3] else output_dir

if (!file.exists(xlsx_path)) {
  stop("Data.xlsx not found at: ", xlsx_path)
}

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)
message("=== Mt Messenger Ecology Figure Pipeline ===")
message("Input:   ", xlsx_path)
message("Figures: ", output_dir)
message("Tables:  ", tables_dir)
message("")

# --- Load data ---
message("Loading data...")
data <- load_all_data(xlsx_path)
message("  Loaded sheets: ", paste(names(data), collapse = ", "))
message("")

# --- Sediment ---
# EM2, EM4, EM8 not required for 2024-2025 report (per Mike)
SEDIMENT_EXCLUDE <- c("EM2", "EM4", "EM8")

message("--- Sediment Plots ---")
if (!is.null(data$SedimentSize)) {
  plot_sediment_size_distribution(data$SedimentSize, output_dir,
                                  exclude_sites = SEDIMENT_EXCLUDE)
}
if (!is.null(data$Sediment)) {
  sed_triggers <- compute_sediment_triggers(data$Sediment)
  plot_sediment_timeseries(data$Sediment, sed_triggers, output_dir,
                           exclude_sites = SEDIMENT_EXCLUDE)
}
message("")

# --- Macro Metrics ---
message("--- Macro Metric Plots ---")
if (!is.null(data$Macro1)) {
  macro_triggers <- compute_macro_triggers(data$Macro1)
  plot_macro_combined(data$Macro1, macro_triggers, output_dir)
  plot_macro_individual(data$Macro1, macro_triggers, output_dir)
}
message("")

# --- NMDS Community Analysis ---
message("--- NMDS & Community Analysis ---")
if (!is.null(data$Community)) {
  community_df <- data$Community
  catchments <- get_catchment_subsets()
  display_names <- get_site_display_names()

  # Apply display names to community data
  community_df <- community_df |>
    mutate(Site = ifelse(Site %in% names(display_names), display_names[Site], Site))

  # All-sites grouped NMDS
  message("All-sites NMDS...")
  nmds_all <- run_site_nmds(community_df)
  if (!is.null(nmds_all)) {
    plot_nmds_grouped(nmds_all, file.path(output_dir, "NMDS_AllSites.jpeg"),
                      title = "All Sites NMDS", shape_title = "Site")
  }

  # Baseline-only NMDS
  message("Baseline NMDS...")
  baseline_df <- community_df |> filter(Period == "Baseline")
  if (nrow(baseline_df) > 3) {
    nmds_base <- run_site_nmds(baseline_df)
    if (!is.null(nmds_base)) {
      plot_nmds_grouped(nmds_base, file.path(output_dir, "BaselineNMDS.jpeg"),
                        title = "Baseline NMDS", shape_title = "Site")
    }
  }

  # Construction-only NMDS
  message("Construction NMDS...")
  construction_df <- community_df |> filter(Period == "Routine Construction")
  if (nrow(construction_df) > 3) {
    nmds_constr <- run_site_nmds(construction_df)
    if (!is.null(nmds_constr)) {
      plot_nmds_grouped(nmds_constr, file.path(output_dir, "ConstructionNMDS.jpeg"),
                        title = "Construction NMDS", shape_title = "Site")
    }
  }

  # Catchment subset NMDS
  for (catchment_name in names(catchments)) {
    message(catchment_name, " NMDS...")
    subset_sites <- catchments[[catchment_name]]
    # Apply display names to subset
    subset_display <- ifelse(subset_sites %in% names(display_names),
                             display_names[subset_sites], subset_sites)
    subset_df <- community_df |> filter(Site %in% subset_display)
    if (nrow(subset_df) > 3) {
      nmds_sub <- run_site_nmds(subset_df)
      if (!is.null(nmds_sub)) {
        safe_name <- gsub("[^A-Za-z0-9_-]", "", gsub(" ", "_", catchment_name))
        plot_nmds_grouped(nmds_sub,
                          file.path(output_dir, paste0("NMDS_", safe_name, ".jpeg")),
                          title = paste(catchment_name, "Sites"),
                          shape_title = paste(catchment_name, "Site"))
      }
    }
  }

  # Per-site NMDS with regression arrows
  message("Per-site NMDS (regression arrows)...")
  plot_nmds_per_site(community_df, output_dir)

  # Per-site NMDS with species labels
  message("Per-site NMDS (species labels)...")
  plot_nmds_per_site_with_species(community_df, output_dir)

  # Indicator species analysis
  message("Indicator species analysis...")
  # All sites
  plot_indicator_species(community_df, output_dir, group_col = "Period",
                         scope_label = "all", tables_dir = tables_dir)
  # Per catchment
  for (catchment_name in names(catchments)) {
    subset_sites <- catchments[[catchment_name]]
    subset_display <- ifelse(subset_sites %in% names(display_names),
                             display_names[subset_sites], subset_sites)
    subset_df <- community_df |> filter(Site %in% subset_display)
    if (nrow(subset_df) > 3 && length(unique(subset_df$Period)) >= 2) {
      safe_name <- gsub("[^A-Za-z0-9_-]", "_", catchment_name)
      plot_indicator_species(subset_df, output_dir, group_col = "Period",
                             scope_label = paste0(safe_name, "_Sites"),
                             tables_dir = tables_dir)
    }
  }
  # Per site
  for (site in unique(community_df$Site)) {
    site_df <- community_df |> filter(Site == site)
    if (length(unique(site_df$Period)) >= 2 && nrow(site_df) > 3) {
      plot_indicator_species(site_df, output_dir, group_col = "Period",
                             scope_label = gsub(" ", "_", site),
                             tables_dir = tables_dir)
    }
  }

  # Species drivers (envfit)
  message("Species drivers (envfit)...")
  export_species_drivers(community_df, tables_dir, scope_label = "all")
  for (catchment_name in names(catchments)) {
    subset_sites <- catchments[[catchment_name]]
    subset_display <- ifelse(subset_sites %in% names(display_names),
                             display_names[subset_sites], subset_sites)
    subset_df <- community_df |> filter(Site %in% subset_display)
    if (nrow(subset_df) > 3) {
      safe_name <- gsub("[^A-Za-z0-9_-]", "_", catchment_name)
      export_species_drivers(subset_df, tables_dir,
                             scope_label = paste0(safe_name, "_Sites"))
    }
  }
  for (site in unique(community_df$Site)) {
    site_df <- community_df |> filter(Site == site)
    if (nrow(site_df) > 3) {
      export_species_drivers(site_df, tables_dir, scope_label = gsub(" ", "_", site))
    }
  }

  # Dissimilarity table
  message("Dissimilarity table...")
  export_dissimilarity_table(community_df, file.path(tables_dir, "Dissimilarity_Table.xlsx"))

  # Combined indicator species (multi-sheet workbook)
  message("Combined indicator species workbook...")
  export_indicator_species_combined(community_df, tables_dir)

  # Indicator species by catchment (baseline vs construction)
  message("Indicator species by catchment...")
  export_indicator_species_by_catchment(community_df, catchments, tables_dir)

  # Combined species drivers with catchment labels
  message("Combined species drivers...")
  export_species_drivers_combined(community_df, catchments, tables_dir)

  # Top species with abundance change per site
  message("Top species with abundance change...")
  export_topspecies_with_abundance(community_df, tables_dir)
}

message("")
message("--- Clarity Plots ---")
if (!is.null(data$Clarity)) {
  if ("Clarity (mm)" %in% names(data$Clarity)) {
    plot_clarity_boxplot(data$Clarity, output_dir)
    plot_clarity_timeseries(data$Clarity, output_dir)
  }
  plot_clarity_ntu_relationship(data$Clarity, output_dir)
} else {
  message("  Skipped: no Clarity sheet found")
}

message("")
message("=== Pipeline Complete ===")
n_figures <- length(list.files(output_dir, recursive = TRUE))
message("Figures generated: ", n_figures, " (", output_dir, ")")
if (tables_dir != output_dir) {
  n_tables <- length(list.files(tables_dir, recursive = TRUE))
  message("Tables generated:  ", n_tables, " (", tables_dir, ")")
}
