# fish_plots.R — Fish trapping catch-per-night plots by catchment
#
# Exports:
#   plot_fish_by_catchment(fish_df, output_dir)

library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
library(patchwork)


# Species category labels for panel titles
FISH_CATEGORY_LABELS <- c(
  B = "Bullies",
  K = "Kokopu",
  E = "Eels",
  FC = "Koura",
  I = "Inanga"
)

# Panel order: Combined first, then species categories
FISH_PANEL_ORDER <- c("Combined", "Bullies", "Eels", "Koura", "Inanga", "Kokopu")

# Catchment -> site mapping for fish data
FISH_CATCHMENT_SITES <- list(
  Mangapepeke = c("EM1", "EM2", "EM3"),
  Mimi = c("EM4", "EM6", "EM8")
)


#' Aggregate fish trapping data to total catch per night.
#'
#' Sums the Number column per Date retrieved × Site × Species category.
#' Shrimp records are excluded. Returns a long-format data frame with
#' a Category column (species label) plus a "Combined" entry for all species.
#'
#' @param fish_df Fish data frame from the workbook `Fish` sheet (via load_all_data()).
#' @return Data frame: Date, Site, Catchment, Category, Catch.
compute_fish_catch_per_night <- function(fish_df) {
  # Filter to relevant categories, exclude shrimp and missing
  valid_cats <- names(FISH_CATEGORY_LABELS)

  df <- fish_df |>
    filter(`Species category (for abundance)` %in% valid_cats,
           !is.na(Date),
           !is.na(Number)) |>
    mutate(
      Category = FISH_CATEGORY_LABELS[`Species category (for abundance)`]
    )

  # Per-category totals
  by_category <- df |>
    group_by(Date, Site, Catchment, Category) |>
    summarise(Catch = sum(Number, na.rm = TRUE), .groups = "drop")

  # Combined totals (all categories summed)
  combined <- df |>
    group_by(Date, Site, Catchment) |>
    summarise(Catch = sum(Number, na.rm = TRUE), .groups = "drop") |>
    mutate(Category = "Combined")

  bind_rows(by_category, combined) |>
    mutate(Category = factor(Category, levels = FISH_PANEL_ORDER)) |>
    # Fill missing site/date/category combos with zero catch
    tidyr::complete(
      tidyr::nesting(Date, Site, Catchment),
      Category,
      fill = list(Catch = 0)
    )
}


#' Build a single fish panel plot.
#'
#' @param panel_df Data filtered to one category.
#' @param category Panel title.
#' @param sites Character vector of all site codes for consistent legend.
#' @param show_x_axis Whether to render x-axis labels.
#' @return ggplot object.
make_fish_panel <- function(panel_df, category, sites, show_x_axis = FALSE) {
  panel_df <- panel_df |>
    mutate(Site = factor(Site, levels = sites))

  p <- ggplot(panel_df, aes(x = Date, y = Catch, colour = Site)) +
    geom_line(linewidth = 0.6, alpha = 0.7) +
    geom_point(size = 2) +
    scale_colour_manual(values = SITE_COLOURS, limits = sites, breaks = sites,
                        drop = FALSE) +
    labs(
      title = category,
      y = "Total Catch per Night",
      x = ""
    ) +
    theme_minimal(base_size = 14) +
    theme(
      axis.title = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 12, hjust = 0)
    ) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y")

  # Baseline end vline
  p <- add_baseline_vline(p)

  # Summer shading
  year_min <- min(year(panel_df$Date), na.rm = TRUE)
  year_max <- max(year(panel_df$Date), na.rm = TRUE)
  p <- add_summer_shading(p, year_min, year_max)

  if (!show_x_axis) {
    p <- p + theme(axis.text.x = element_blank(),
                   axis.ticks.x = element_blank())
  } else {
    p <- p + theme(axis.text.x = element_text(angle = 90, hjust = 0.5))
  }

  p
}


#' Plot fish catch-per-night by catchment.
#'
#' Produces a 3×2 patchwork figure per catchment with panels:
#' Combined, Bullies, Eels, Koura, Inanga, Kokopu.
#'
#' @param fish_df Fish data frame from the workbook `Fish` sheet (via load_all_data()).
#' @param output_dir Output directory for saved plots.
plot_fish_by_catchment <- function(fish_df, output_dir) {
  catch_df <- compute_fish_catch_per_night(fish_df)

  for (catchment_name in names(FISH_CATCHMENT_SITES)) {
    sites <- FISH_CATCHMENT_SITES[[catchment_name]]
    catch_sub <- catch_df |> filter(Catchment == catchment_name, Site %in% sites)

    if (nrow(catch_sub) == 0) {
      message("  Skipping fish ", catchment_name, " \u2014 no data")
      next
    }

    # Build panels in layout order (3 rows × 2 cols)
    # Row 1: Combined, Bullies
    # Row 2: Eels, Koura
    # Row 3: Inanga, Kokopu
    panels <- list()
    for (i in seq_along(FISH_PANEL_ORDER)) {
      cat_name <- FISH_PANEL_ORDER[i]
      panel_data <- catch_sub |> filter(Category == cat_name)

      # Bottom row shows x-axis
      show_x <- i >= 5

      if (nrow(panel_data) > 0) {
        panels[[i]] <- make_fish_panel(panel_data, cat_name, sites,
                                       show_x_axis = show_x)
      } else {
        panels[[i]] <- ggplot() +
          labs(title = cat_name) +
          theme_void() +
          theme(plot.title = element_text(face = "bold", size = 12))
      }
    }

    # Arrange with patchwork: 3 rows × 2 cols + shared legend at bottom
    combined <- (panels[[1]] | panels[[2]]) /
                (panels[[3]] | panels[[4]]) /
                (panels[[5]] | panels[[6]]) +
      plot_layout(guides = "collect") &
      theme(legend.position = "bottom")

    safe_name <- tolower(gsub("[^A-Za-z0-9_]", "", gsub("[ -]", "_", catchment_name)))
    save_plot(combined, file.path(output_dir, paste0("fish_", safe_name, ".jpeg")),
              width = 10, height = 10)
  }
}
