# test-clarity-plots.R — clarity figure construction (regression for the
# Date-axis band rectangles).
source(file.path(ROOT, "src", "r", "helpers", "plotting_style.R"))
source(file.path(ROOT, "src", "r", "helpers", "clarity_plots.R"))

make_clarity_df <- function() {
  sites <- c("CM1", "CM2", "CM3", "CM4", "CMDSF13", "EM4")
  dates <- seq(as.Date("2021-06-01"), as.Date("2024-06-01"), by = "2 months")
  df <- expand.grid(Site = sites, Date = dates, stringsAsFactors = FALSE)
  # Values kept inside the plotted 300-1300 band so no points are clipped
  # (which would raise an unrelated "Removed rows" warning).
  df[["Clarity (mm)"]] <- rep(seq(350, 1250, length.out = nrow(df) / 6),
                              each = 6)[seq_len(nrow(df))]
  df
}

# Capture the ggplot instead of writing a JPEG: building the plot
# (ggplot_build) exercises the scale transform where the bug lived, with no
# graphics device — which CI does not provide. The pipeline helpers are sourced
# into the global env, so the override and its restore target that env.
capture_plot <- function(expr) {
  orig <- get("save_plot", envir = globalenv())
  withr::defer(assign("save_plot", orig, envir = globalenv()),
               envir = parent.frame())
  captured <- NULL
  assign("save_plot",
         function(p, path, ...) { captured <<- p; invisible(NULL) },
         envir = globalenv())
  force(expr)
  captured
}

test_that("clarity time-series renders without a date-scale coercion warning", {
  # Bare numeric -Inf/Inf on a Date x-axis hard-errors on older ggplot2/scales
  # ("transform_date() works with objects of class <Date> only") and warns on
  # newer ("converted to a <Date>"). Date-typed bounds must do neither.
  p <- capture_plot(plot_clarity_timeseries(make_clarity_df(), tempdir()))
  expect_false(is.null(p))
  expect_no_warning(ggplot2::ggplot_build(p), message = "Date scale|numeric")
})

test_that("clarity time-series band rectangles use Date-typed x bounds", {
  p <- capture_plot(plot_clarity_timeseries(make_clarity_df(), tempdir()))
  rect_layer <- p$layers[[1]]
  expect_s3_class(rect_layer$data$x_left, "Date")
  expect_s3_class(rect_layer$data$x_right, "Date")
})
