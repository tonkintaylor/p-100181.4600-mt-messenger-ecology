# clarity_plots.R — Water clarity plots (boxplot, time-series, NTU scatter)
#
# Reimplements ref/mike_extra_request/Site clarity plots.R as
# reusable functions matching the existing helper pattern.
#
# Exports:
#   plot_clarity_boxplot(clarity_df, output_dir)
#   plot_clarity_timeseries(clarity_df, output_dir)
#   plot_clarity_ntu_relationship(clarity_df, output_dir)

library(ggplot2)
library(dplyr)
library(tibble)

# --- Constants ---
CLARITY_SITE_ORDER <- c("CM1", "CM2", "CM3", "CM4", "CMDSF13", "EM4")

# Band boundaries (metres)
CLARITY_BAND_A <- 0.93
CLARITY_BAND_B <- 0.76
CLARITY_BAND_C <- 0.61

# Band boundaries (mm, for time-series)
CLARITY_BAND_A_MM <- 930
CLARITY_BAND_B_MM <- 760
CLARITY_BAND_C_MM <- 610


# ============================================================================
# Plot 1 — Clarity boxplot with attribute bands
# ============================================================================

#' Boxplot + jittered scatter of clarity (m) per site with A/B/C/D bands.
#'
#' @param clarity_df Data frame with columns Site, Clarity (mm).
#' @param output_dir Output directory for saved plots.
plot_clarity_boxplot <- function(clarity_df, output_dir) {
  df <- clarity_df %>%
    mutate(
      clarity_m = as.numeric(`Clarity (mm)`) / 1000,
      Site = factor(Site, levels = CLARITY_SITE_ORDER),
      x_site = as.numeric(Site)
    ) %>%
    filter(!is.na(Site), !is.na(clarity_m))

  if (nrow(df) == 0) {
    warning("No valid clarity data for boxplot")
    return(invisible(NULL))
  }

  # Y-axis limits with padding
  y_rng <- range(df$clarity_m, na.rm = TRUE)
  pad_y <- 0.04 * diff(y_rng)
  if (!is.finite(pad_y) || pad_y == 0) pad_y <- 0.05
  y_lower <- y_rng[1] - pad_y
  y_upper <- y_rng[2] + pad_y

  # Attribute bands
  bands_m <- tibble(
    band = factor(c("A", "B", "C", "D"), levels = c("A", "B", "C", "D")),
    ymin = c(CLARITY_BAND_A, CLARITY_BAND_B, CLARITY_BAND_C, y_lower),
    ymax = c(y_upper, CLARITY_BAND_A, CLARITY_BAND_B, CLARITY_BAND_C)
  )

  # X padding
  n_sites <- length(CLARITY_SITE_ORDER)
  pad_x <- 0.7
  x_left  <- 1 - pad_x
  x_right <- n_sites + pad_x

  p <- ggplot() +
    geom_rect(
      data = bands_m,
      aes(xmin = x_left, xmax = x_right, ymin = ymin, ymax = ymax, fill = band),
      inherit.aes = FALSE,
      alpha = 0.22
    ) +
    geom_boxplot(
      data = df,
      aes(x = x_site, y = clarity_m, group = Site),
      fill = "lightgrey", outlier.shape = NA, width = 0.6
    ) +
    geom_jitter(
      data = df,
      aes(x = x_site, y = clarity_m),
      width = 0.15, size = 3, alpha = 0.9, colour = "grey20"
    ) +
    geom_hline(
      yintercept = c(CLARITY_BAND_A, CLARITY_BAND_B, CLARITY_BAND_C),
      linetype = "dashed", colour = "grey35"
    ) +
    scale_x_continuous(
      breaks = seq_len(n_sites),
      labels = CLARITY_SITE_ORDER,
      limits = c(x_left, x_right),
      expand = c(0, 0)
    ) +
    coord_cartesian(ylim = c(y_lower, y_upper), expand = FALSE) +
    scale_fill_manual(
      values = c(A = "#1b9e77", B = "#7570b3", C = "#e6ab02", D = "#d95f02"),
      name = "Band"
    ) +
    labs(
      title = "Clarity by Site: Boxplot + Scatter with attribute bands",
      x = "Site",
      y = "Clarity (m)"
    ) +
    theme_bw() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "right"
    )

  save_plot(p, file.path(output_dir, "clarity_boxplot.jpeg"),
            width = 10, height = 6)
  message("  Saved: clarity_boxplot")
}


# ============================================================================
# Plot 2 — Clarity time-series faceted by site
# ============================================================================

#' Faceted clarity time-series (mm) per site with attribute bands.
#'
#' @param clarity_df Data frame with columns Site, Date, Clarity (mm).
#' @param output_dir Output directory for saved plots.
plot_clarity_timeseries <- function(clarity_df, output_dir) {
  long <- clarity_df %>%
    transmute(
      Date = as.Date(Date),
      Site = factor(Site, levels = CLARITY_SITE_ORDER),
      Value = as.numeric(`Clarity (mm)`)
    ) %>%
    filter(!is.na(Site), !is.na(Value), !is.na(Date))

  if (nrow(long) == 0) {
    warning("No valid clarity data for time-series")
    return(invisible(NULL))
  }

  # Attribute bands (mm)
  bands <- tibble::tibble(
    ymin = c(CLARITY_BAND_A_MM, CLARITY_BAND_B_MM, CLARITY_BAND_C_MM, 300),
    ymax = c(1300, CLARITY_BAND_A_MM, CLARITY_BAND_B_MM, CLARITY_BAND_C_MM),
    band = c("A", "B", "C", "D")
  ) %>%
    mutate(y_mid = (ymin + ymax) / 2)

  # Full-width bands on a Date x-axis. Use Date-typed +/-Inf, not bare numeric
  # -Inf/Inf: a <Date> is a classed numeric, so these carry the infinities while
  # still passing scales' `inherits(x, "Date")` check. Bare numeric -Inf/Inf
  # hard-errors on older ggplot2/scales ("transform_date() works with objects of
  # class <Date> only") and only warns ("converted to a <Date>") on newer ones.
  bands$x_left  <- structure(rep(-Inf, nrow(bands)), class = "Date")
  bands$x_right <- structure(rep(Inf,  nrow(bands)), class = "Date")

  p <- ggplot() +
    geom_rect(
      data = bands,
      aes(xmin = x_left, xmax = x_right, ymin = ymin, ymax = ymax, fill = band),
      alpha = 0.55
    ) +
    geom_text(
      data = bands,
      aes(x = x_left, y = y_mid, label = band),
      hjust = -0.2, vjust = 0.5,
      size = 2, fontface = "bold", colour = "black"
    ) +
    geom_line(
      data = long,
      aes(x = Date, y = Value, group = Site),
      colour = "black",
      linewidth = 0.6
    ) +
    geom_point(
      data = long,
      aes(x = Date, y = Value),
      colour = "grey25",
      size = 2
    ) +
    facet_wrap(~ Site, ncol = 2) +
    scale_x_date(date_breaks = "3 months", date_labels = "%b %y") +
    scale_y_continuous(
      breaks = seq(300, 1300, 150),
      expand = c(0, 0)
    ) +
    coord_cartesian(ylim = c(300, 1300)) +
    scale_fill_manual(
      values = c("A" = "green", "B" = "yellow", "C" = "orange", "D" = "red"),
      guide = "none"
    ) +
    theme_bw(base_size = 8) +
    theme(
      strip.text = element_text(size = 7),
      strip.background = element_rect(fill = "white"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none",
      panel.spacing = grid::unit(0.6, "lines")
    ) +
    labs(
      title = "Water Quality Changes Over Time At Each Site",
      x = "Date",
      y = "Clarity (mm)"
    )

  save_plot(p, file.path(output_dir, "clarity_timeseries.jpeg"),
            width = 12, height = 10)
  message("  Saved: clarity_timeseries")
}


# ============================================================================
# Plot 3 — NTU continuous sensor vs lab scatter with regression
# ============================================================================

#' Scatter plot of NTU lab vs continuous sensor with OLS regression.
#'
#' @param clarity_df Data frame with columns Site, NTU-Continous Sensor, NTU-Lab.
#' @param output_dir Output directory for saved plots.
plot_clarity_ntu_relationship <- function(clarity_df, output_dir) {
  # Handle the column name typo ("Continous" vs "Continuous")
  ntu_sensor_col <- if ("NTU-Continous Sensor" %in% names(clarity_df)) {
    "NTU-Continous Sensor"
  } else if ("NTU-Continuous Sensor" %in% names(clarity_df)) {
    "NTU-Continuous Sensor"
  } else {
    warning("NTU sensor column not found — skipping NTU relationship plot")
    return(invisible(NULL))
  }

  if (!"NTU-Lab" %in% names(clarity_df)) {
    warning("NTU-Lab column not found — skipping NTU relationship plot")
    return(invisible(NULL))
  }

  plot_df <- clarity_df %>%
    transmute(
      Site = factor(Site, levels = CLARITY_SITE_ORDER),
      x = as.numeric(.data[[ntu_sensor_col]]),
      y = as.numeric(`NTU-Lab`)
    ) %>%
    filter(!is.na(Site), !is.na(x), !is.na(y))

  if (nrow(plot_df) < 2) {
    warning("Insufficient NTU data for regression (n < 2)")
    return(invisible(NULL))
  }

  # Fit OLS
  fit <- lm(y ~ x, data = plot_df)
  coefs <- coef(fit)
  slope <- unname(coefs["x"])
  intercept <- unname(coefs["(Intercept)"])
  r2 <- summary(fit)$r.squared
  rmse <- sqrt(mean((plot_df$y - predict(fit, newdata = plot_df))^2))
  n <- nrow(plot_df)

  label_txt <- sprintf(
    "y = %.2fx + %.2f\nR\u00B2 = %.3f\nRMSE = %.2f\nn = %d",
    slope, intercept, r2, rmse, n
  )

  # Axis limits (minimum 60)
  x_max <- max(60, max(plot_df$x, na.rm = TRUE))
  y_max <- max(60, max(plot_df$y, na.rm = TRUE))

  p <- ggplot(plot_df, aes(x = x, y = y, colour = Site)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "black") +
    geom_point(size = 3, alpha = 0.95) +
    geom_smooth(method = "lm", formula = y ~ x, se = FALSE,
                colour = "red", linewidth = 0.8) +
    annotate(
      "label",
      x = 0.98 * x_max, y = 0.98 * y_max,
      label = label_txt,
      hjust = 1, vjust = 1,
      size = 3.5
    ) +
    coord_cartesian(xlim = c(0, x_max), ylim = c(0, y_max)) +
    labs(
      title = "NTU: Continuous Sensor vs NTU: Lab",
      x = "NTU-Continuous Sensor",
      y = "NTU-Lab",
      colour = "Site"
    ) +
    theme_bw() +
    theme(
      legend.position = "right",
      plot.title = element_text(hjust = 0.5)
    )

  save_plot(p, file.path(output_dir, "clarity_ntu_relationship.jpeg"),
            width = 8, height = 7)
  message("  Saved: clarity_ntu_relationship")
}
