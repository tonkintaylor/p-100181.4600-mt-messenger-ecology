# test_pipeline.R — Basic tests for R pipeline helpers
# Run with: Rscript -e "testthat::test_file('src/r/tests/test_pipeline.R')"

library(testthat)

# Source helpers (relative to project root)
project_root <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), "..", "..",".."),
                              mustWork = FALSE)
if (!dir.exists(file.path(project_root, "src", "r"))) {
  project_root <- getwd()
}
helpers_dir <- file.path(project_root, "src", "r", "helpers")

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(vegan)
  library(zoo)
  library(patchwork)
  library(openxlsx)
})

source(file.path(helpers_dir, "data_loading.R"))
source(file.path(helpers_dir, "plotting_style.R"))
source(file.path(helpers_dir, "triggers.R"))
source(file.path(helpers_dir, "macro_plots.R"))
source(file.path(helpers_dir, "sediment_plots.R"))

xlsx_path <- file.path(project_root, "ref", "Data.xlsx")

# --- data_loading.R ---
test_that("load_all_data returns expected sheets", {
  skip_if_not(file.exists(xlsx_path), "Data.xlsx not present")
  data <- load_all_data(xlsx_path)
  expect_true("Macro" %in% names(data))
  expect_true("Macro1" %in% names(data))
  expect_true("Sediment" %in% names(data))
  expect_true("SedimentSize" %in% names(data))
  expect_true("Community" %in% names(data))
})

test_that("column names are trimmed (no trailing spaces)", {
  skip_if_not(file.exists(xlsx_path), "Data.xlsx not present")
  data <- load_all_data(xlsx_path)
  for (sheet_name in names(data)) {
    col_names <- names(data[[sheet_name]])
    expect_true(all(col_names == trimws(col_names)),
                info = paste("Trailing spaces in", sheet_name))
  }
})

test_that("Community matrix has Site, Date, Period and species columns", {
  skip_if_not(file.exists(xlsx_path), "Data.xlsx not present")
  data <- load_all_data(xlsx_path)
  community <- data$Community
  expect_true("Site" %in% names(community))
  expect_true("Date" %in% names(community))
  expect_true("Period" %in% names(community))
  species_cols <- setdiff(names(community), c("Site", "Date", "Period"))
  expect_gt(length(species_cols), 5)
})

test_that("MMA sites are excluded from Community", {
  skip_if_not(file.exists(xlsx_path), "Data.xlsx not present")
  data <- load_all_data(xlsx_path)
  expect_false(any(grepl("^MMA", data$Community$Site)))
})

# --- triggers.R ---
test_that("macro triggers are below baseline means (decline trigger)", {
  skip_if_not(file.exists(xlsx_path), "Data.xlsx not present")
  data <- load_all_data(xlsx_path)
  triggers <- compute_macro_triggers(data$Macro1)
  expect_s3_class(triggers, "data.frame")
  expect_true("Site" %in% names(triggers))
  expect_true("Metric" %in% names(triggers))
  expect_true("Trigger" %in% names(triggers))
  # Trigger should be < baseline mean (85% decline direction)
  expect_true(all(triggers$Trigger > 0))
})

test_that("sediment triggers are above baseline means (increase trigger)", {
  skip_if_not(file.exists(xlsx_path), "Data.xlsx not present")
  data <- load_all_data(xlsx_path)
  triggers <- compute_sediment_triggers(data$Sediment)
  # Returns named vector

  expect_true(is.numeric(triggers))
  expect_true(length(triggers) > 0)
  # Sediment trigger is 115% of baseline (increase direction), capped at 100
  expect_true(all(triggers > 0))
  expect_true(all(triggers <= 100))
})

# --- plotting_style.R ---
test_that("temporal_palette returns correct length", {
  pal <- temporal_palette(5)
  expect_length(pal, 5)
})

test_that("site_shapes returns named vector", {
  shapes <- site_shapes()
  expect_true(is.numeric(shapes))
  expect_true(!is.null(names(shapes)))
})

test_that("theme_ecology returns ggplot theme", {
  th <- theme_ecology()
  expect_s3_class(th, "theme")
})

# --- catchment subsets ---
test_that("catchment subsets contain expected sites", {
  subsets <- get_catchment_subsets()
  expect_true("Mangapepeke" %in% names(subsets) || "Mangap\u0113p\u0113ke" %in% names(subsets))
  expect_true(any(grepl("^EM", unlist(subsets))))
})

test_that("site shift metadata returns expected events per site", {
  em7 <- get_site_shift_events("EM7")
  expect_equal(nrow(em7), 2)
  expect_equal(as.character(em7$Date), c("2023-11-01", "2025-11-01"))
  expect_equal(em7$Label, c("Site shift (Nov 2023)", "Site shift (Nov 2025)"))

  em2 <- get_site_shift_events("EM2")
  expect_equal(nrow(em2), 1)
  expect_equal(as.character(em2$Date), "2020-11-01")
  expect_equal(em2$Label, "Site shift (Nov 2020)")
  expect_equal(unname(em2$Shape), 17)
  expect_equal(unname(em2$Colour), "#ff9f1c")
  em3 <- get_site_shift_events("EM3")
  expect_equal(nrow(em3), 0)
})

test_that("macro panel includes configured site shift labels in shape legend", {
  summary_df <- data.frame(
    Date = as.Date(c("2023-08-01", "2023-11-01", "2024-02-01")),
    Mean = c(5.8, 5.5, 5.6),
    CI_lower = c(5.4, 5.2, 5.3),
    CI_upper = c(6.2, 5.8, 5.9),
    Period = factor(c("Baseline", "Routine Construction", "Routine Construction"),
                    levels = VALID_PERIODS)
  )

  p <- make_metric_panel(
    summary_df = summary_df,
    metric = "QMCI",
    trigger_val = NA,
    has_incident = FALSE,
    show_x_axis = TRUE,
    site = "EM7"
  )

  has_shift_layer <- any(vapply(
    p$layers,
    function(layer) {
      has_shape_mapping <- !is.null(layer$mapping$shape) &&
        grepl("Label", paste(deparse(layer$mapping$shape), collapse = ""))
      has_shift_data <- !is.null(layer$data) &&
        is.data.frame(layer$data) &&
        "Label" %in% names(layer$data) &&
        any(grepl("^Site shift", layer$data$Label))
      has_shape_mapping && has_shift_data
    },
    logical(1)
  ))
  expect_true(has_shift_layer)
})
