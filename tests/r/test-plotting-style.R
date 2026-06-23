# test-plotting-style.R — figure-helper styling logic.
source(file.path(ROOT, "src", "r", "helpers", "plotting_style.R"))

make_date_plot <- function(dates) {
  ggplot2::ggplot(
    data.frame(Date = as.Date(dates), y = seq_along(dates)),
    ggplot2::aes(x = Date, y = y)
  ) + ggplot2::geom_point()
}

# BASELINE_END is 2022-03-31.

test_that("baseline vline is added when BASELINE_END is within the plotted range", {
  p <- make_date_plot(c("2021-01-01", "2023-01-01"))
  out <- add_baseline_vline(p)
  expect_equal(length(out$layers), length(p$layers) + 1L)
})

test_that("baseline vline is skipped when BASELINE_END is outside the plotted range", {
  # RPD/LDV monitoring began in 2024 — the 2022 baseline line cannot display,
  # so it must not be added (otherwise ggplot clips it and warns).
  p <- make_date_plot(c("2024-08-22", "2026-04-30"))
  out <- add_baseline_vline(p)
  expect_equal(length(out$layers), length(p$layers))
})
