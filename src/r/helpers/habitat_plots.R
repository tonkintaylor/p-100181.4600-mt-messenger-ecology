# habitat_plots.R — RPD and LDV per-catchment and per-site time-series plots
#
# Exports:
#   plot_rpd_by_catchment(rpd_df, output_dir)
#   plot_ldv_by_catchment(ldv_df, output_dir)
#   plot_rpd_per_site(rpd_df, output_dir, sites)
#   plot_ldv_per_site(ldv_df, output_dir, sites)

library(ggplot2)
library(dplyr)
library(lubridate)


#' Plot mean RPD per catchment with 95% CI error bars.
#'
#' Produces one plot per catchment with a trace per site.
#' Format matches SAM time-series plots (no trigger levels).
#'
#' @param rpd_df Data frame with columns: Site, Date, Count, Mean, StdDev,
#'   CI_Lower, CI_Upper.
#' @param output_dir Output directory for saved plots.
plot_rpd_by_catchment <- function(rpd_df, output_dir) {
  catchments <- get_catchment_subsets()

  for (catchment_name in c("Mangapepeke", "Mimi")) {
    sites <- catchments[[catchment_name]]
    catch_df <- rpd_df |> filter(Site %in% sites)

    if (nrow(catch_df) == 0) {
      message("  Skipping RPD ", catchment_name, " — no data")
      next
    }

    p <- ggplot(catch_df, aes(x = Date, y = Mean, colour = Site)) +
      geom_line(linewidth = 0.6, alpha = 0.7) +
      geom_point(size = 2.5) +
      scale_colour_manual(values = SITE_COLOURS) +
      labs(
        title = paste(catchment_name, "\u2014 Mean Residual Pool Depth"),
        x = "",
        y = "Mean RPD (cm)"
      ) +
      theme_minimal(base_size = 14) +
      theme(
        legend.position = "right",
        axis.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 90, hjust = 0.5)
      ) +
      scale_x_date(
        date_breaks = "3 months", date_labels = "%b %y",
        limits = range(catch_df$Date, na.rm = TRUE)
      )

    # Baseline end vline
    p <- add_baseline_vline(p)

    # Summer shading
    year_min <- min(year(catch_df$Date), na.rm = TRUE)
    year_max <- max(year(catch_df$Date), na.rm = TRUE)
    p <- add_summer_shading(p, year_min, year_max)

    safe_name <- tolower(gsub("[^A-Za-z0-9_]", "", gsub("[ -]", "_", catchment_name)))
    save_plot(p, file.path(output_dir, paste0("rpd_", safe_name, ".jpeg")))
  }
}


#' Plot LDV (CV%) per catchment.
#'
#' Produces one plot per catchment with a trace per site.
#' No error bars — CV% is a single derived statistic per survey.
#'
#' @param ldv_df Data frame with columns: Site, Date, Season, CV_pct.
#' @param output_dir Output directory for saved plots.
plot_ldv_by_catchment <- function(ldv_df, output_dir) {
  catchments <- get_catchment_subsets()

  for (catchment_name in c("Mangapepeke", "Mimi")) {
    sites <- catchments[[catchment_name]]
    catch_df <- ldv_df |> filter(Site %in% sites)

    if (nrow(catch_df) == 0) {
      message("  Skipping LDV ", catchment_name, " — no data")
      next
    }

    p <- ggplot(catch_df, aes(x = Date, y = CV_pct, colour = Site)) +
      geom_line(linewidth = 0.6, alpha = 0.7) +
      geom_point(size = 2.5) +
      scale_colour_manual(values = SITE_COLOURS) +
      labs(
        title = paste(catchment_name, "\u2014 Low-flow Depth Variability"),
        x = "",
        y = "CV (%)"
      ) +
      theme_minimal(base_size = 14) +
      theme(
        legend.position = "right",
        axis.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 90, hjust = 0.5)
      ) +
      scale_x_date(
        date_breaks = "3 months", date_labels = "%b %y",
        limits = range(catch_df$Date, na.rm = TRUE)
      )

    # Baseline end vline
    p <- add_baseline_vline(p)

    # Summer shading
    year_min <- min(year(catch_df$Date), na.rm = TRUE)
    year_max <- max(year(catch_df$Date), na.rm = TRUE)
    p <- add_summer_shading(p, year_min, year_max)

    safe_name <- tolower(gsub("[^A-Za-z0-9_]", "", gsub("[ -]", "_", catchment_name)))
    save_plot(p, file.path(output_dir, paste0("ldv_", safe_name, ".jpeg")))
  }
}


#' Plot mean RPD for individual sites.
#'
#' Produces one plot per site showing the RPD time-series with 95% CI
#' error bars. Style matches catchment plots but with a single trace.
#'
#' @param rpd_df Data frame with columns: Site, Date, Count, Mean, StdDev,
#'   CI_Lower, CI_Upper.
#' @param output_dir Output directory for saved plots.
#' @param sites Character vector of site codes to plot individually.
plot_rpd_per_site <- function(rpd_df, output_dir, sites) {
  for (site in sites) {
    site_df <- rpd_df |> filter(Site == site)

    if (nrow(site_df) == 0) {
      message("  Skipping RPD per-site ", site, " \u2014 no data")
      next
    }

    p <- ggplot(site_df, aes(x = Date, y = Mean)) +
      geom_line(linewidth = 0.6, alpha = 0.7, colour = SITE_COLOURS[[site]]) +
      geom_point(size = 2.5, colour = SITE_COLOURS[[site]]) +
      geom_errorbar(
        aes(ymin = CI_Lower, ymax = CI_Upper),
        width = 16, linewidth = 0.5, colour = SITE_COLOURS[[site]]
      ) +
      labs(
        title = paste(site, "\u2014 Mean Residual Pool Depth"),
        x = "",
        y = "Mean RPD (cm)"
      ) +
      theme_minimal(base_size = 14) +
      theme(
        axis.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 90, hjust = 0.5)
      ) +
      scale_x_date(
        date_breaks = "3 months", date_labels = "%b %y",
        limits = range(site_df$Date, na.rm = TRUE)
      )

    p <- add_baseline_vline(p)

    year_min <- min(year(site_df$Date), na.rm = TRUE)
    year_max <- max(year(site_df$Date), na.rm = TRUE)
    p <- add_summer_shading(p, year_min, year_max)

    save_plot(p, file.path(output_dir, paste0("rpd_", site, ".jpeg")))
  }
}


#' Plot LDV (CV%) for individual sites.
#'
#' Produces one plot per site showing the LDV time-series.
#' Style matches catchment plots but with a single trace.
#'
#' @param ldv_df Data frame with columns: Site, Date, Season, CV_pct.
#' @param output_dir Output directory for saved plots.
#' @param sites Character vector of site codes to plot individually.
plot_ldv_per_site <- function(ldv_df, output_dir, sites) {
  for (site in sites) {
    site_df <- ldv_df |> filter(Site == site)

    if (nrow(site_df) == 0) {
      message("  Skipping LDV per-site ", site, " \u2014 no data")
      next
    }

    p <- ggplot(site_df, aes(x = Date, y = CV_pct)) +
      geom_line(linewidth = 0.6, alpha = 0.7, colour = SITE_COLOURS[[site]]) +
      geom_point(size = 2.5, colour = SITE_COLOURS[[site]]) +
      labs(
        title = paste(site, "\u2014 Low-flow Depth Variability"),
        x = "",
        y = "CV (%)"
      ) +
      theme_minimal(base_size = 14) +
      theme(
        axis.title = element_text(face = "bold"),
        axis.text.x = element_text(angle = 90, hjust = 0.5)
      ) +
      scale_x_date(
        date_breaks = "3 months", date_labels = "%b %y",
        limits = range(site_df$Date, na.rm = TRUE)
      )

    p <- add_baseline_vline(p)

    year_min <- min(year(site_df$Date), na.rm = TRUE)
    year_max <- max(year(site_df$Date), na.rm = TRUE)
    p <- add_summer_shading(p, year_min, year_max)

    save_plot(p, file.path(output_dir, paste0("ldv_", site, ".jpeg")))
  }
}
