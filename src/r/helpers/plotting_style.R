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
BASELINE_END <- as.Date("2022-02-28")
CONSTRUCTION_START <- as.Date("2022-07-01")

PERIOD_COLORS <- c(

  "Baseline" = "#ff9f1c",
  "Routine Construction" = "#2ec4b6",
  "Incident" = "#e71d36"
)

ALL_SITES <- c("EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8")


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
         device = "pdf", bg = "white")
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
add_baseline_vline <- function(p) {
  p + geom_vline(
    xintercept = as.numeric(BASELINE_END),
    linetype = "dashed", linewidth = 0.8, alpha = 0.7
  )
}
