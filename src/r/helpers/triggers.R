# triggers.R — Compute ecological trigger levels
#
# Exports:
#   compute_macro_triggers(macro1_df)    -> data frame of site/metric/trigger
#   compute_sediment_triggers(sed_df)    -> named vector of site -> trigger

library(dplyr)
library(tidyr)

#' Compute macro metric trigger levels.
#'
#' For each site and metric (QMCI, EPTrich, EPTabun):
#' 1. Average replicates per date within baseline period
#' 2. Take mean of those per-date averages
#' 3. Multiply by 0.85 (15% decline threshold)
#'
#' @param macro1_df Macro1 data frame with columns: Site, Date, Period, QMCI, EPTrich, EPTabun
#' @return Data frame with columns: Site, Metric, Trigger
compute_macro_triggers <- function(macro1_df) {
  metrics <- c("QMCI", "EPTrich", "EPTabun")

  baseline <- macro1_df |>
    filter(Period == "Baseline")

  if (nrow(baseline) == 0) {
    warning("No baseline data found for macro triggers")
    return(data.frame(Site = character(), Metric = character(), Trigger = numeric()))
  }

  # Average replicates per site/date first
  date_means <- baseline |>
    group_by(Site, Date) |>
    summarise(across(all_of(metrics), ~ mean(.x, na.rm = TRUE)), .groups = "drop")

  # Then take mean of date-averages per site
  triggers <- date_means |>
    group_by(Site) |>
    summarise(across(all_of(metrics), ~ mean(.x, na.rm = TRUE) * 0.85), .groups = "drop") |>
    pivot_longer(cols = all_of(metrics), names_to = "Metric", values_to = "Trigger")

  triggers
}


#' Compute sediment SAM1 trigger levels.
#'
#' For each site: mean(baseline SAM1) * 1.15, capped at 100.
#'
#' @param sediment_df Sediment data frame with columns: Site, Date, Period, SAM1
#' @return Named vector: site -> trigger value
compute_sediment_triggers <- function(sediment_df) {
  baseline <- sediment_df |>
    filter(Period == "Baseline")

  if (nrow(baseline) == 0) {
    warning("No baseline data found for sediment triggers")
    return(setNames(numeric(0), character(0)))
  }

  triggers <- baseline |>
    group_by(Site) |>
    summarise(Trigger = min(mean(SAM1, na.rm = TRUE) * 1.15, 100), .groups = "drop")

  setNames(triggers$Trigger, triggers$Site)
}
