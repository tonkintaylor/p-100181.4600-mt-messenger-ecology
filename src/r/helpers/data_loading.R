# data_loading.R — Read and prepare Data.xlsx for the Mt Messenger ecology pipeline
#
# Exports:
#   load_all_data(xlsx_path) -> list of data frames

library(readxl)
library(dplyr)
library(tidyr)

#' Load all sheets from Data.xlsx and clean them for analysis.
#'
#' @param xlsx_path Path to the Data.xlsx file.
#' @return Named list: Macro, Macro1, Sediment, SedimentSize, MacroSpecies, Community, Clarity
load_all_data <- function(xlsx_path) {
  stopifnot(file.exists(xlsx_path))

  sheets <- excel_sheets(xlsx_path)
  message("Available sheets: ", paste(sheets, collapse = ", "))

  data <- list()

  # --- Macro (summary metrics per site/date) ---
  if ("Macro" %in% sheets) {
    data$Macro <- read_excel(xlsx_path, sheet = "Macro") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- Macro1 (replicate-level metrics) ---
  if ("Macro1" %in% sheets) {
    data$Macro1 <- read_excel(xlsx_path, sheet = "Macro1") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- Sediment (SAM1/SAM3 time-series) ---
  if ("Sediment" %in% sheets) {
    data$Sediment <- read_excel(xlsx_path, sheet = "Sediment") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- SedimentSize (grain-size fractions) ---
  if ("SedimentSize" %in% sheets) {
    data$SedimentSize <- read_excel(xlsx_path, sheet = "SedimentSize") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- MacroSpecies (long-format species tallies) ---
  if ("MacroSpecies" %in% sheets) {
    data$MacroSpecies <- read_excel(xlsx_path, sheet = "MacroSpecies") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date)) |>
      filter(!grepl("^MMA", Site))
  }

  # --- Clarity (water clarity monitoring) ---
  if ("Clarity" %in% sheets) {
    data$Clarity <- read_excel(xlsx_path, sheet = "Clarity") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- RPD (residual pool depth summary) ---
  if ("RPD" %in% sheets) {
    data$RPD <- read_excel(xlsx_path, sheet = "RPD") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- LDV (low-flow depth variability, CV%) ---
  if ("LDV" %in% sheets) {
    data$LDV <- read_excel(xlsx_path, sheet = "LDV") |>
      clean_colnames() |>
      mutate(Date = as.Date(Date))
  }

  # --- Community (wide-format species matrix, derived from MacroSpecies) ---
  if (!is.null(data$MacroSpecies)) {
    data$Community <- derive_community_matrix(data$MacroSpecies)
  }

  data
}


#' Strip trailing/leading whitespace from all column names.
clean_colnames <- function(df) {
  names(df) <- trimws(names(df))
  df
}


#' Derive wide-format community matrix from long-format MacroSpecies.
#'
#' Averages replicates per Site+Date+Species, then pivots to wide.
#' Returns a data frame with columns: Site, Date, Period, <species columns...>
derive_community_matrix <- function(macro_species) {
  # Average replicates per site/date/species
  mean_tallies <- macro_species |>
    group_by(Site, Date, Species) |>
    summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")

  # Get Period from original data (take first non-NA per Site+Date)
  period_lookup <- macro_species |>
    distinct(Site, Date, .keep_all = TRUE) |>
    select(Site, Date, Period = Phase)

  # Pivot to wide
  wide <- mean_tallies |>
    pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

  # Join period info
  wide <- wide |>
    left_join(period_lookup, by = c("Site", "Date"))

  # Reorder columns: metadata first, then species
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(wide), meta_cols)
  wide[, c(meta_cols, species_cols)]
}


#' Define site groups and catchment subsets.
#' @return Named list of catchment -> site vectors.
get_catchment_subsets <- function() {
  list(
    Mangapepeke = c("EM1", "EM2", "EM3", "EM5"),
    Mimi = c("EM4", "EM5", "EM7", "EM8"),
    `Soft-bottom` = c("EM1", "EM2", "EM4", "EM8"),
    `Hard-bottom` = c("EM3", "EM5", "EM7")
  )
}


#' Map site codes to display names (control sites get " Control" suffix).
get_site_display_names <- function() {
  c(
    EM1 = "EM1 Control",
    EM2 = "EM2",
    EM3 = "EM3",
    EM4 = "EM4 Control",
    EM5 = "EM5 Control",
    EM7 = "EM7",
    EM8 = "EM8"
  )
}


#' Map sites to their catchment.
get_catchment_lookup <- function() {
  c(
    EM1 = "Mangapepeke",
    `EM1 Control` = "Mangapepeke",
    EM2 = "Mangapepeke",
    EM3 = "Mangapepeke",
    EM4 = "Mimi",
    `EM4 Control` = "Mimi",
    EM5 = "Mimi",
    `EM5 Control` = "Mimi",
    EM7 = "Mimi",
    EM8 = "Mimi"
  )
}
