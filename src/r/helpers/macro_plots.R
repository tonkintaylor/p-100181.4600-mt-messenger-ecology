# macro_plots.R — Macroinvertebrate metric plots with CI error bars
#
# Exports:
#   plot_macro_combined(macro1_df, triggers_df, output_dir)
#   plot_macro_individual(macro1_df, triggers_df, output_dir)

library(ggplot2)
library(dplyr)
library(lubridate)
library(patchwork)

VALID_PERIODS <- c("Baseline", "Routine Construction", "Incident")

#' Normalise Period column: trim whitespace and convert to factor.
#' Warns on unexpected values.
normalise_period <- function(df) {
  df$Period <- trimws(as.character(df$Period))
  unexpected <- setdiff(unique(df$Period), VALID_PERIODS)
  if (length(unexpected) > 0) {
    warning("Unexpected Period values: ", paste(unexpected, collapse = ", "))
  }
  df$Period <- factor(df$Period, levels = VALID_PERIODS)
  df
}

# Y-axis limits matching legacy R scripts
MACRO_YLIMS <- list(
  QMCI = c(0, 8),
  EPTrich = c(0, 101),
  EPTabun = c(0, 101)
)

MACRO_LABELS <- c(
  QMCI = "QMCI",
  EPTrich = "%EPT Richness",
  EPTabun = "%EPT Abundance"
)

PANEL_LABELS <- c("a)", "b)", "c)")


#' Compute per-date summary statistics (mean + 95% CI) for a metric.
#'
#' @param site_df Data frame filtered to one site.
#' @param metric Column name.
#' @return Data frame with Date, Mean, CI_lower, CI_upper, Period.
compute_metric_summary <- function(site_df, metric) {
  cap <- ifelse(metric == "QMCI", 8, 100)

  site_df |>
    group_by(Date, Period) |>
    summarise(
      Mean = mean(.data[[metric]], na.rm = TRUE),
      SD = sd(.data[[metric]], na.rm = TRUE),
      N = n(),
      .groups = "drop"
    ) |>
    mutate(
      SE = dplyr::if_else(N > 1L, SD / sqrt(N), 0),
      t_crit = dplyr::if_else(N > 1L, qt(0.975, df = N - 1), NA_real_),
      CI_lower = dplyr::if_else(N > 1L, pmax(Mean - t_crit * SE, 0), Mean),
      CI_upper = dplyr::if_else(N > 1L, pmin(Mean + t_crit * SE, cap), Mean)
    ) |>
    select(-t_crit)
}


#' Build the colour scale with Trigger Level in legend.
#'
#' Maps Period values + "Trigger Level" to colours. The legend shows
#' points for period entries and a solid line for the trigger.
#' Uses explicit breaks/limits so legend entries are always consistent.
#' @param has_incident Whether to include Incident in the scale.
#' @return A scale_colour_manual layer.
build_colour_scale <- function(has_incident = FALSE) {
  if (has_incident) {
    vals <- c(
      "Baseline" = "#ff9f1c",
      "Routine Construction" = "#2ec4b6",
      "Incident" = "#e71d36",
      "Trigger Level" = "black"
    )
    brks <- c("Baseline", "Routine Construction", "Incident",
              "Trigger Level")
    overrides <- list(
      linetype = c("blank", "blank", "blank", "solid"),
      shape = c(16, 16, 16, NA),
      linewidth = c(NA, NA, NA, 0.8)
    )
  } else {
    vals <- c(
      "Baseline" = "#ff9f1c",
      "Routine Construction" = "#2ec4b6",
      "Trigger Level" = "black"
    )
    brks <- c("Baseline", "Routine Construction", "Trigger Level")
    overrides <- list(
      linetype = c("blank", "blank", "solid"),
      shape = c(16, 16, NA),
      linewidth = c(NA, NA, 0.8)
    )
  }
  scale_colour_manual(
    values = vals,
    breaks = brks,
    limits = brks,
    guide = guide_legend(override.aes = overrides)
  )
}


#' Create a single metric panel plot with legend-friendly trigger + baseline.
#'
#' @param summary_df Output of compute_metric_summary().
#' @param metric Metric name.
#' @param trigger_val Trigger level (or NA).
#' @param has_incident Whether site has Incident period data.
#' @param show_x_axis Whether to show x-axis labels.
#' @return ggplot object.
make_metric_panel <- function(summary_df, metric, trigger_val = NA,
                              has_incident = FALSE, show_x_axis = FALSE) {
  # Build trigger data frame for legend-mapped geom_hline
  trigger_df <- if (!is.na(trigger_val)) {
    data.frame(yintercept = trigger_val, Lines = "Trigger Level")
  } else {
    NULL
  }

  p <- ggplot(summary_df, aes(x = Date, y = Mean, colour = Period)) +
    geom_errorbar(
      aes(ymin = CI_lower, ymax = CI_upper),
      width = 16, linewidth = 0.5
    ) +
    geom_point(size = 2.5) +
    coord_cartesian(ylim = MACRO_YLIMS[[metric]]) +
    labs(y = MACRO_LABELS[[metric]], x = "") +
    theme_light(base_size = 12) +
    theme(
      legend.title = element_blank(),
      legend.text = element_text(size = 9),
      legend.position = "right"
    )

  # Trigger line mapped to colour legend
  if (!is.null(trigger_df)) {
    p <- p + geom_hline(
      aes(yintercept = yintercept, colour = Lines),
      data = trigger_df, linewidth = 0.8, show.legend = TRUE
    )
  }

  # Colour scale with trigger in legend
  p <- p + build_colour_scale(has_incident = has_incident)

  # Baseline vline — mapped to linetype legend for "Baseline \nMonitoring End"
  p <- p +
    geom_vline(
      aes(xintercept = as.numeric(BASELINE_END),
          linetype = "Baseline \nMonitoring End"),
      colour = "black", linewidth = 0.8
    ) +
    scale_linetype_manual(
      name = NULL,
      values = c("Baseline \nMonitoring End" = "dashed"),
      guide = guide_legend(
        label.hjust = 0,
        label.theme = element_text(size = 9),
        label.position = "right",
        override.aes = list(colour = "black", linewidth = 0.8)
      )
    )

  # Summer shading
  year_min <- min(year(summary_df$Date), na.rm = TRUE)
  year_max <- max(year(summary_df$Date), na.rm = TRUE)
  p <- add_summer_shading(p, year_min, year_max)

  # X-axis formatting
  p <- p + scale_x_date(date_breaks = "3 months", date_labels = "%b %y")
  if (!show_x_axis) {
    p <- p + theme(axis.text.x = element_blank(),
                   axis.ticks.x = element_blank())
  } else {
    p <- p + theme(axis.text.x = element_text(angle = 90, hjust = 0.5))
  }

  p
}


#' Plot 3-panel combined macro metric figure per site.
#'
#' Panels are labelled a), b), c) and share a common legend that includes
#' period colours, trigger level, and baseline monitoring end.
#'
#' @param macro1_df Macro1 data frame.
#' @param triggers_df Data frame from compute_macro_triggers().
#' @param output_dir Output directory.
plot_macro_combined <- function(macro1_df, triggers_df, output_dir) {
  macro1_df <- normalise_period(macro1_df)
  metrics <- c("QMCI", "EPTrich", "EPTabun")
  sites <- sort(unique(macro1_df$Site))

  for (site in sites) {
    site_df <- macro1_df |> filter(Site == site)
    has_incident <- "Incident" %in% as.character(site_df$Period)
    panels <- list()

    for (i in seq_along(metrics)) {
      metric <- metrics[i]
      summary_df <- compute_metric_summary(site_df, metric)

      trigger_val <- triggers_df |>
        filter(Site == site, Metric == metric) |>
        pull(Trigger)
      if (length(trigger_val) == 0) trigger_val <- NA

      show_x <- (i == length(metrics))
      panels[[i]] <- make_metric_panel(
        summary_df, metric, trigger_val,
        has_incident = has_incident, show_x_axis = show_x
      )
    }

    # Combine with patchwork: panel tags a), b), c) and shared legend
    combined <- panels[[1]] / panels[[2]] / panels[[3]] +
      plot_annotation(
        title = site,
        tag_levels = list(PANEL_LABELS),
        theme = theme(
          plot.title = element_text(face = "bold", size = 14, hjust = 0.5)
        )
      ) +
      plot_layout(guides = "collect") &
      theme(plot.tag = element_text(size = 12, face = "plain"))

    safe_site <- gsub(" ", "_", site)
    save_plot(combined, file.path(output_dir, paste0(safe_site, "_combined.jpg")),
              width = 9, height = 12)
  }
}


#' Plot individual metric figures per site (one plot per site per metric).
#'
#' @param macro1_df Macro1 data frame.
#' @param triggers_df Data frame from compute_macro_triggers().
#' @param output_dir Output directory.
plot_macro_individual <- function(macro1_df, triggers_df, output_dir) {
  macro1_df <- normalise_period(macro1_df)
  metrics <- c("QMCI", "EPTrich", "EPTabun")
  metric_filenames <- c(QMCI = "qmci", EPTrich = "ept_rich", EPTabun = "ept_abun")
  sites <- sort(unique(macro1_df$Site))

  for (site in sites) {
    site_df <- macro1_df |> filter(Site == site)
    has_incident <- "Incident" %in% as.character(site_df$Period)
    safe_site <- gsub(" ", "_", site)

    for (metric in metrics) {
      summary_df <- compute_metric_summary(site_df, metric)

      trigger_val <- triggers_df |>
        filter(Site == site, Metric == metric) |>
        pull(Trigger)
      if (length(trigger_val) == 0) trigger_val <- NA

      p <- make_metric_panel(
        summary_df, metric, trigger_val,
        has_incident = has_incident, show_x_axis = TRUE
      ) +
        labs(title = paste(site, "\u2014", MACRO_LABELS[[metric]])) +
        theme(plot.title = element_text(face = "bold", size = 14))

      fname <- paste0(safe_site, "_", metric_filenames[[metric]], ".jpg")
      save_plot(p, file.path(output_dir, fname))
    }
  }
}
