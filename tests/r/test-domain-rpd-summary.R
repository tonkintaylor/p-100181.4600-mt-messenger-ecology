src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/rpd.R")
src_data("domains/rpd_summary.R")

# Write an "RPD Summary" sheet with 3 filler rows then header+data at row 4,
# so read_excel(skip=3) reads the header as column names (as the real sheet is).
rpd_xlsx <- function(df) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "RPD Summary")
  for (i in seq_len(3)) {
    openxlsx::writeData(wb, "RPD Summary", x = paste0("filler ", i),
                        startRow = i, startCol = 1, colNames = FALSE)
  }
  openxlsx::writeData(wb, "RPD Summary", x = df, startRow = 4, colNames = TRUE)
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

# Fixture exercising: single-survey CI, within-season pooling (EM_B, two Spring
# 2024 surveys), Dec -> Summer(next year) labelling (EM_C), and N=1 -> NA CI.
fixture_df <- function() {
  data.frame(
    Site        = c("EM_A", "EM_B", "EM_B", "EM_C", "EM_D", "EM_E"),
    Date        = as.Date(c("2024-08-15", "2024-09-10", "2024-11-20",
                            "2024-12-15", "2024-06-01", "2025-03-10")),
    Count       = c(4L, 2L, 2L, 3L, 1L, 3L),
    `Mean (cm)` = c(10, 10, 14, 20, 5, 15),
    `Std Dev`   = c(6, 2, 2, 2 * sqrt(3), NA, 3),
    `CI Lower`  = c(5, 8, 12, 17, NA, 12),
    `CI Upper`  = c(15, 12, 16, 23, NA, 18),
    check.names = FALSE, stringsAsFactors = FALSE)
}

get_row <- function(df, site, season, year) {
  as.list(df[df$Site == site & df$Season == season & df$Year == year, ])
}

test_that("returns a DomainResult with RpdSummary + schema columns", {
  result <- process_rpd_summary_domain(rpd_xlsx(fixture_df()))
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_equal(names(result$data$RpdSummary), RPD_SUMMARY_COLUMNS)
  # EM_A/Winter, EM_B/Spring (pooled), EM_C/Summer, EM_D/Winter, EM_E/Summer.
  expect_equal(nrow(result$data$RpdSummary), 5L)
})

test_that("March is grouped with the summer round (not autumn)", {
  df <- process_rpd_summary_domain(rpd_xlsx(fixture_df()))$data$RpdSummary
  e <- get_row(df, "EM_E", "Summer", 2025)   # 2025-03-10 -> Summer 2025
  expect_equal(nrow(df[df$Site == "EM_E", ]), 1L)
  expect_equal(e$Mean, 15)
  expect_false("Autumn" %in% df$Season[df$Site == "EM_E"])
})

test_that("single-survey season: t-based 95% CI half-width", {
  df <- process_rpd_summary_domain(rpd_xlsx(fixture_df()))$data$RpdSummary
  a <- get_row(df, "EM_A", "Winter", 2024)
  expect_equal(a$N, 4L)
  expect_equal(a$Mean, 10)
  # qt(0.975, 3) * 6 / sqrt(4)
  expect_equal(a$CI95, qt(0.975, 3) * 6 / 2, tolerance = 1e-6)
})

test_that("within-season surveys are pooled into one combined sample", {
  df <- process_rpd_summary_domain(rpd_xlsx(fixture_df()))$data$RpdSummary
  b <- get_row(df, "EM_B", "Spring", 2024)
  expect_equal(b$N, 4L)                 # 2 + 2
  expect_equal(b$Mean, 12)              # (2*10 + 2*14)/4
  # pooled_var = [ (1*4 + 1*4) + (2*(10-12)^2 + 2*(14-12)^2) ] / 3 = 24/3 = 8
  expect_equal(b$CI95, qt(0.975, 3) * sqrt(8) / sqrt(4), tolerance = 1e-6)
})

test_that("December is labelled as the following year's Summer", {
  df <- process_rpd_summary_domain(rpd_xlsx(fixture_df()))$data$RpdSummary
  c_ <- get_row(df, "EM_C", "Summer", 2025)   # 2024-12-15 -> Summer 2025
  expect_equal(c_$N, 3L)
  expect_equal(c_$Mean, 20)
  expect_equal(c_$CI95, qt(0.975, 2) * (2 * sqrt(3)) / sqrt(3), tolerance = 1e-6)
})

test_that("single measurement (N=1) yields NA CI", {
  df <- process_rpd_summary_domain(rpd_xlsx(fixture_df()))$data$RpdSummary
  d <- get_row(df, "EM_D", "Winter", 2024)
  expect_equal(d$N, 1L)
  expect_equal(d$Mean, 5)
  expect_true(is.na(d$CI95))
})

test_that("missing 'RPD Summary' sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Other" = data.frame(x = 1)), tmp)
  result <- process_rpd_summary_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
})
