# habitat_plots.R — RPD and LDV per-catchment time-series plots
#
# Exports:
#   plot_rpd_by_catchment(rpd_df, output_dir)
#   plot_ldv_by_catchment(ldv_df, output_dir)

library(ggplot2)
library(dplyr)
library(lubridate)


# Site colour palette — distinct colours for each EM site on the same plot.
SITE_COLOURS <- c(
  "EM1" = "#1b9e77",
  "EM2" = "#d95f02",
  "EM3" = "#7570b3",
  "EM4" = "#e7298a",
  "EM5" = "#66a61e",
  "EM7" = "#e6ab02",
  "EM8" = "#a6761d"
)


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
      geom_errorbar(
        aes(ymin = CI_Lower, ymax = CI_Upper),
        width = 16, linewidth = 0.4, alpha = 0.6
      ) +
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
