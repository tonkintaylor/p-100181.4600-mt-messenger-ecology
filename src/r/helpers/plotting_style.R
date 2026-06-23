# plotting_style.R — Shared theme, palettes, and save helpers
#
# Exports:
#   theme_ecology()       - consistent ggplot2 theme
#   temporal_palette(n)   - red-to-blue colour ramp for n dates
#   site_shapes()         - named vector of shape codes per site
#   save_plot(p, path, width, height) - save as JPG at 300 DPI
#   BASELINE_END          - date marking end of baseline monitoring

library(ggplot2)

# --- Constants ---
BASELINE_END <- as.Date("2022-03-31")
CONSTRUCTION_START <- as.Date("2022-07-01")

PERIOD_COLORS <- c(

  "Baseline" = "#ff9f1c",
  "Routine Construction" = "#2ec4b6",
  "Incident" = "#e71d36"
)

ALL_SITES <- c("EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8")

# Site colour palette — distinct colours for each EM site on the same plot.
SITE_COLOURS <- c(
  "EM1" = "#1b9e77",
  "EM2" = "#d95f02",
  "EM3" = "#7570b3",
  "EM4" = "#e7298a",
  "EM5" = "#66a61e",
  "EM6" = "#377eb8",
  "EM7" = "#e6ab02",
  "EM8" = "#a6761d"
)

SITE_SHIFT_SHAPE <- 8  # asterisk — less likely to be mistaken for a data point

SITE_SHIFT_EVENTS <- data.frame(
  Site = c("EM2", "EM7", "EM7"),
  Date = as.Date(c("2020-11-01", "2023-11-01", "2025-11-01")),
  Label = c("* Site shifted (Nov 2020)", "* Site shifted (Nov 2023)", "* Site shifted (Nov 2025)"),
  Period = c("Baseline", "Routine Construction", "Routine Construction"),
  stringsAsFactors = FALSE
)


#' Custom legend key glyph: coloured background with solid black symbol.
#'
#' Draws a filled rectangle using the mapped colour as background, then a
#' solid black point on top. If shape is NA (e.g. for Trigger Level entries)
#' draws only a line instead.
draw_key_coloured_bg <- function(data, params, size) {
  bg_col <- if (!is.null(data$colour) && !is.na(data$colour)) data$colour else "grey80"
  shp <- if (!is.null(data$shape) && !is.na(data$shape)) data$shape else 16
  grid::grobTree(
    grid::rectGrob(gp = grid::gpar(fill = bg_col, col = NA)),
    grid::pointsGrob(0.5, 0.5, pch = shp,
                     gp = grid::gpar(col = "black", fill = "black"),
                     size = unit(0.8, "char"))
  )
}


#' Minimal ecology theme matching the R scripts' theme_minimal(base_size=14).
theme_ecology <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      legend.position = "right",
      legend.box = "vertical",
      axis.title = element_text(face = "bold"),
      legend.key.size = unit(0.6, "cm"),
      legend.text = element_text(size = 10)
    )
}


#' Generate n colours on a red-to-blue temporal gradient.
#' @param n Number of distinct time points.
#' @return Character vector of hex colours.
temporal_palette <- function(n) {
  colorRampPalette(c("red", "blue"))(n)
}


#' Site shape mapping for NMDS plots.
#' Uses standard R pch values matching the original scripts.
site_shapes <- function() {
  c(
    "EM1 Control" = 16,
    "EM2" = 17,
    "EM3" = 15,
    "EM4 Control" = 3,
    "EM5 Control" = 4,
    "EM7" = 8,
    "EM8" = 11,
    # Fallbacks for raw site codes
    "EM1" = 16,
    "EM4" = 3,
    "EM5" = 4

  )
}


#' Save a ggplot as JPEG at 300 DPI.
#'
#' @param p A ggplot object.
#' @param path Output file path (should end in .jpg or .jpeg).
#' @param width Width in inches (default 8).
#' @param height Height in inches (default 6).
#' @param dpi Resolution (default 300).
save_plot <- function(p, path, width = 8, height = 6, dpi = 300) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  ggsave(path, plot = p, width = width, height = height, dpi = dpi,
         device = "jpeg", bg = "white", create.dir = TRUE)
  message("  Saved: ", path)
}


#' Save a ggplot as both JPEG and PDF.
save_plot_both <- function(p, base_path, width = 8, height = 6, dpi = 300) {
  save_plot(p, paste0(base_path, ".jpeg"), width = width, height = height, dpi = dpi)
  dir.create(dirname(base_path), showWarnings = FALSE, recursive = TRUE)
  ggsave(paste0(base_path, ".pdf"), plot = p, width = width, height = height,
         device = "pdf", bg = "white", create.dir = TRUE)
}


#' Add summer shading (Jan-Mar) rectangles to a ggplot with date x-axis.
#'
#' @param p A ggplot object with a Date x-axis.
#' @param year_min First year to shade.
#' @param year_max Last year to shade.
#' @return Modified ggplot with shading annotations.
add_summer_shading <- function(p, year_min, year_max) {
  shading <- data.frame(
    xmin = as.Date(paste0(year_min:year_max, "-01-01")),
    xmax = as.Date(paste0(year_min:year_max, "-03-31"))
  )
  p + geom_rect(
    data = shading,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
    fill = "gray", alpha = 0.15, inherit.aes = FALSE
  )
}


#' Add baseline end vertical line.
#'
#' Skips the line when BASELINE_END falls outside the plotted date range (e.g.
#' RPD/LDV monitoring began well after baseline), since ggplot would otherwise
#' clip the off-screen line and emit a "Removed 1 row" warning. The plotted
#' dates default to the plot's own `Date` column.
#'
#' @param p A ggplot object with a Date x-axis.
#' @param plot_dates Optional vector of plotted dates; defaults to `p$data$Date`.
add_baseline_vline <- function(p, plot_dates = NULL) {
  if (is.null(plot_dates) && !is.null(p$data) && "Date" %in% names(p$data)) {
    plot_dates <- p$data[["Date"]]
  }
  if (!is.null(plot_dates)) {
    rng <- suppressWarnings(range(as.Date(plot_dates), na.rm = TRUE))
    if (all(is.finite(rng)) && (BASELINE_END < rng[1] || BASELINE_END > rng[2])) {
      return(p)
    }
  }
  p + geom_vline(
    xintercept = BASELINE_END,
    linetype = "dashed", linewidth = 0.8, alpha = 0.7
  )
}


#' Return configured site shift events for a site.
#'
#' @param site Site code (e.g. EM2, EM7).
#' @return Data frame with Date, Label, Shape, and Colour columns.
get_site_shift_events <- function(site) {
  events <- SITE_SHIFT_EVENTS |>
    dplyr::filter(Site == site) |>
    dplyr::mutate(
      Shape = SITE_SHIFT_SHAPE,
      Colour = unname(PERIOD_COLORS[Period])
    ) |>
    dplyr::select(Date, Label, Shape, Colour)

  events
}


#' Annotate nearest data points to site-shift dates with "*".
#'
#' For each shift event, finds the closest row in plot_data by date and places
#' a "*" text annotation above that point. No legend entry is added.
#'
#' @param p A ggplot object.
#' @param site Site code (e.g. "EM2").
#' @param plot_data Data frame with the plotted data points.
#' @param x_col Name of the date column in plot_data.
#' @param y_col Name of the y-value column in plot_data.
#' @param y_nudge Vertical offset above the data point for the "*".
#' @return The plot with "*" annotations, or unchanged if no shift events.
add_site_shift_annotations <- function(p, site, plot_data, x_col = "Date",
                                       y_col = "Mean", y_nudge = 0) {
  shift_events <- get_site_shift_events(site)
  if (nrow(shift_events) == 0) return(p)

  for (i in seq_len(nrow(shift_events))) {
    diffs <- abs(as.numeric(plot_data[[x_col]] - shift_events$Date[i]))
    nearest_idx <- which.min(diffs)
    ann_x <- plot_data[[x_col]][nearest_idx]
    ann_y <- plot_data[[y_col]][nearest_idx] + y_nudge

    p <- p + annotate("text", x = ann_x, y = ann_y,
                       label = "*", size = 8, hjust = 0.5, vjust = -0.1,
                       colour = "black", fontface = "bold")
  }
  p
}
