# macro_plots.R — Macroinvertebrate metric plots with CI error bars
#
# Exports:
#   plot_macro_combined(macro1_df, triggers_df, output_dir)
#   plot_macro_individual(macro1_df, triggers_df, output_dir)

library(ggplot2)
library(dplyr)
library(patchwork)

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


#' Compute per-date summary statistics (mean + 95% CI) for a metric.
#'
#' @param site_df Data frame filtered to one site.
#' @param metric Column name.
#' @return Data frame with Date, Mean, CI_lower, CI_upper, Period.
compute_metric_summary <- function(site_df, metric) {
  site_df |>
    group_by(Date, Period) |>
    summarise(
      Mean = mean(.data[[metric]], na.rm = TRUE),
      SD = sd(.data[[metric]], na.rm = TRUE),
      N = n(),
      SE = SD / sqrt(N),
      CI_lower = pmax(Mean - qt(0.975, df = N - 1) * SE, 0),
      CI_upper = pmin(Mean + qt(0.975, df = N - 1) * SE,
                      ifelse(metric == "QMCI", 8, 100)),
      .groups = "drop"
    ) |>
    mutate(
      CI_lower = ifelse(is.na(CI_lower), Mean, CI_lower),
      CI_upper = ifelse(is.na(CI_upper), Mean, CI_upper)
    )
}


#' Create a single metric panel plot.
#'
#' @param summary_df Output of compute_metric_summary().
#' @param metric Metric name.
#' @param trigger_val Trigger level (or NA).
#' @param show_x_axis Whether to show x-axis labels.
#' @return ggplot object.
make_metric_panel <- function(summary_df, metric, trigger_val = NA, show_x_axis = FALSE) {
  p <- ggplot(summary_df, aes(x = Date, y = Mean, colour = Period)) +
    geom_point(size = 2.5) +
    geom_errorbar(
      aes(ymin = CI_lower, ymax = CI_upper),
      width = 16, linewidth = 0.5
    ) +
    scale_colour_manual(values = c(
      "Baseline" = "#ff9f1c",
      "Routine Construction" = "#2ec4b6",
      "Incident" = "#e71d36"
    )) +
    coord_cartesian(ylim = MACRO_YLIMS[[metric]]) +
    labs(y = MACRO_LABELS[[metric]], x = "") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")

  # Trigger line
  if (!is.na(trigger_val)) {
    p <- p + geom_hline(yintercept = trigger_val, linetype = "solid",
                        linewidth = 0.8, colour = "black")
  }

  # Baseline vline
  p <- p + geom_vline(xintercept = as.numeric(BASELINE_END),
                      linetype = "dashed", linewidth = 0.8, alpha = 0.7)

  # Summer shading
  year_min <- min(year(summary_df$Date), na.rm = TRUE)
  year_max <- max(year(summary_df$Date), na.rm = TRUE)
  p <- add_summer_shading(p, year_min, year_max)

  # X-axis formatting
  p <- p + scale_x_date(date_breaks = "3 months", date_labels = "%b %y")
  if (!show_x_axis) {
    p <- p + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
  } else {
    p <- p + theme(axis.text.x = element_text(angle = 90, hjust = 0.5))
  }

  p
}


#' Plot 3-panel combined macro metric figure per site.
#'
#' @param macro1_df Macro1 data frame.
#' @param triggers_df Data frame from compute_macro_triggers().
#' @param output_dir Output directory.
plot_macro_combined <- function(macro1_df, triggers_df, output_dir) {
  metrics <- c("QMCI", "EPTrich", "EPTabun")
  sites <- sort(unique(macro1_df$Site))

  for (site in sites) {
    site_df <- macro1_df |> filter(Site == site)
    panels <- list()

    for (i in seq_along(metrics)) {
      metric <- metrics[i]
      summary_df <- compute_metric_summary(site_df, metric)

      trigger_val <- triggers_df |>
        filter(Site == site, Metric == metric) |>
        pull(Trigger)
      if (length(trigger_val) == 0) trigger_val <- NA

      show_x <- (i == length(metrics))
      panels[[i]] <- make_metric_panel(summary_df, metric, trigger_val, show_x)
    }

    # Combine with patchwork
    combined <- panels[[1]] / panels[[2]] / panels[[3]] +
      plot_annotation(title = site, theme = theme(plot.title = element_text(face = "bold", size = 14)))

    save_plot(combined, file.path(output_dir, paste0(site, "DRAFT.jpg")),
              width = 9, height = 12)
  }
}


#' Plot individual metric figures per site (one plot per site per metric).
#'
#' @param macro1_df Macro1 data frame.
#' @param triggers_df Data frame from compute_macro_triggers().
#' @param output_dir Output directory.
plot_macro_individual <- function(macro1_df, triggers_df, output_dir) {
  metrics <- c("QMCI", "EPTrich", "EPTabun")
  metric_filenames <- c(QMCI = "qmci", EPTrich = "rich", EPTabun = "abun")
  sites <- sort(unique(macro1_df$Site))

  # Create subdirectory for DRAFT versions
  draft_dir <- file.path(output_dir, "metric_plots_jpeg")
  dir.create(draft_dir, showWarnings = FALSE, recursive = TRUE)

  for (site in sites) {
    site_df <- macro1_df |> filter(Site == site)

    for (metric in metrics) {
      summary_df <- compute_metric_summary(site_df, metric)

      trigger_val <- triggers_df |>
        filter(Site == site, Metric == metric) |>
        pull(Trigger)
      if (length(trigger_val) == 0) trigger_val <- NA

      p <- make_metric_panel(summary_df, metric, trigger_val, show_x_axis = TRUE) +
        labs(title = paste(site, "\u2014", MACRO_LABELS[[metric]])) +
        theme(
          legend.position = "right",
          plot.title = element_text(face = "bold", size = 14)
        )

      # Save with both naming conventions
      fname_short <- paste0(site, "_", metric_filenames[[metric]], ".jpg")
      fname_draft <- paste0(site, "_", metric, "_DRAFT.jpg")

      save_plot(p, file.path(output_dir, fname_short))
      save_plot(p, file.path(draft_dir, fname_draft))
    }
  }
}
