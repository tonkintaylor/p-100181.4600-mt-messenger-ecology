# sediment_plots.R — Sediment size distribution + SAM time-series plots
#
# Exports:
#   plot_sediment_size_distribution(sed_size_df, output_dir)
#   plot_sediment_timeseries(sed_df, triggers, output_dir)

library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)


#' Plot stacked bar charts of sediment grain-size distribution per site.
#'
#' Uses ColorBrewer "Paired" palette. Adds "Construction Begins" annotation.
#'
#' @param sed_size_df SedimentSize data frame with Date, Site, Period, and size fraction columns.
#' @param output_dir Output directory for saved plots.
#' @param exclude_sites Character vector of site codes to skip.
plot_sediment_size_distribution <- function(sed_size_df, output_dir,
                                            exclude_sites = character(0)) {
  # Identify size fraction columns (everything after Site, Date, Period metadata)
  meta_cols <- c("Date", "Site", "Period", "Phase", "Season")
  size_cols <- setdiff(names(sed_size_df), meta_cols)
  size_cols <- size_cols[!grepl("^SAM", size_cols)]

  if (length(size_cols) == 0) {
    warning("No size fraction columns found in SedimentSize data")
    return(invisible(NULL))
  }

  sites <- sort(unique(sed_size_df$Site))
  sites <- setdiff(sites, exclude_sites)

  for (site in sites) {
    site_df <- sed_size_df |>
      filter(Site == site) |>
      arrange(Date)

    # Pivot to long format for stacking
    long_df <- site_df |>
      select(Date, all_of(size_cols)) |>
      pivot_longer(cols = all_of(size_cols), names_to = "SizeClass", values_to = "Percentage") |>
      mutate(
        Date = format(Date, "%d/%m/%Y"),
        Date = factor(Date, levels = unique(Date)),
        SizeClass = factor(SizeClass, levels = size_cols)
      )

    # Find construction start index
    constr_idx <- which(site_df$Period != "Baseline")[1]

    p <- ggplot(long_df, aes(x = Date, y = Percentage, fill = SizeClass)) +
      geom_bar(stat = "identity", position = "stack", width = 0.7) +
      scale_fill_brewer(palette = "Paired") +
      labs(
        title = paste("Sediment Size Distribution for", site),
        x = "Sampling Date",
        y = "Percentage",
        fill = "Sediment Size"
      ) +
      ylim(0, 105) +
      theme_minimal(base_size = 14) +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 11),
        axis.text.y = element_text(size = 11),
        legend.text = element_text(size = 11),
        legend.title = element_text(size = 14)
      )

    # Add construction line if applicable
    if (!is.na(constr_idx) && constr_idx > 1) {
      p <- p +
        geom_vline(xintercept = constr_idx - 0.5, linetype = "dashed",
                   linewidth = 1.5, colour = "black") +
        annotate("text", x = constr_idx - 0.5, y = 85,
                 label = "Construction Begins", angle = 90,
                 vjust = -0.5, hjust = 0.5, size = 3.5)
    }

    save_plot(p, file.path(output_dir, paste0("SedimentSize_", site, "_A3.png")),
              width = 12, height = 8)
  }
}


#' Plot SAM1 and SAM3 time-series per site with trigger levels.
#'
#' @param sed_df Sediment data frame with Date, Site, Period, SAM1, SAM3.
#' @param triggers Named vector of site -> SAM1 trigger value.
#' @param output_dir Output directory.
#' @param exclude_sites Character vector of site codes to skip.
plot_sediment_timeseries <- function(sed_df, triggers, output_dir,
                                     exclude_sites = character(0)) {
  sites <- sort(unique(sed_df$Site))
  sites <- setdiff(sites, exclude_sites)

  for (site in sites) {
    site_df <- sed_df |>
      filter(Site == site) |>
      arrange(Date)

    trigger_val <- triggers[site]

    for (metric in c("SAM1", "SAM3")) {
      p <- ggplot(site_df, aes(x = Date, y = .data[[metric]], colour = Period)) +
        geom_point(size = 2.5) +
        scale_colour_manual(values = c(
          "Baseline" = "#ff9f1c",
          "Routine Construction" = "#2ec4b6",
          "Incident" = "#e71d36"
        )) +
        ylim(0, 102) +
        labs(
          title = paste(site, "\u2014", metric),
          x = "",
          y = paste0(metric, " Mean Sediment Cover (%)")
        ) +
        theme_minimal(base_size = 14) +
        theme(
          legend.position = "right",
          axis.title = element_text(face = "bold")
        ) +
        scale_x_date(date_breaks = "3 months", date_labels = "%b %y") +
        theme(axis.text.x = element_text(angle = 90, hjust = 0.5))

      # Trigger level
      if (!is.na(trigger_val)) {
        p <- p + geom_hline(yintercept = trigger_val, linetype = "solid",
                            linewidth = 0.8, colour = "black")
      }

      # Baseline end vline
      p <- add_baseline_vline(p)

      # Summer shading
      year_min <- min(year(site_df$Date))
      year_max <- max(year(site_df$Date))
      p <- add_summer_shading(p, year_min, year_max)

      save_plot(p, file.path(output_dir, paste0(site, "_", metric, "_plot.jpeg")))
    }
  }
}
