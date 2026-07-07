src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("domains/field_wq.R")

# Write a synthetic "FieldWQ" sheet and return the xlsx path.
field_wq_xlsx <- function(df) {
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "FieldWQ")
  openxlsx::writeData(wb, "FieldWQ", x = df, colNames = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  tmp
}

fixture_df <- function() {
  data.frame(
    Season                    = c("Spring", "Spring", "Summer", "Summer"),
    Site                      = c("EM1", "EM6", "EM2", "EM9"),
    Date                      = as.Date(c("2025-11-24", "2025-11-17",
                                          "2026-02-23", NA)),
    `Time taken`              = as.POSIXct(c("1899-12-31 12:30:00", NA,
                                             "1899-12-31 13:25:00", NA),
                                           tz = "UTC"),
    `Water temperature`       = c(13.9, 11.3, 14.3, 9),
    pH                        = c(NA, 6.89, 7.46, 7),
    `Specific conductivity`   = c(162.2, 117.7, 191.6, 100),
    `Dissolved oxygen (mg/L)` = c(10.47, 11.34, 88.5, 9),   # 88.5 is a source error
    `Dissolved oxygen (%)`    = c(101.7, 105.0, 87.0, 90),
    check.names = FALSE, stringsAsFactors = FALSE)
}

test_that("returns a DomainResult with FieldWQ + schema columns", {
  result <- process_field_wq_domain(field_wq_xlsx(fixture_df()))
  expect_s3_class(result, "DomainResult")
  expect_true(result$ok())
  expect_equal(names(result$data$FieldWQ), FIELDWQ_COLUMNS)
  # EM9 row has NA Date -> dropped; 3 rows remain.
  expect_equal(nrow(result$data$FieldWQ), 3L)
})

test_that("catchment derived, season/year set, values faithful", {
  df <- process_field_wq_domain(field_wq_xlsx(fixture_df()))$data$FieldWQ
  em1 <- as.list(df[df$Site == "EM1", ])
  em6 <- as.list(df[df$Site == "EM6", ])
  em2 <- as.list(df[df$Site == "EM2", ])

  expect_equal(em1$Catchment, "Mangapepeke")   # EM1-EM3
  expect_equal(em6$Catchment, "Mimi")           # everything else
  expect_equal(em1$Season, "Spring")
  expect_equal(em1$Year, 2025L)
  expect_equal(em2$Season, "Summer")
  expect_equal(em2$Year, 2026L)

  expect_equal(em1$WaterTempC, 13.9)
  expect_true(is.na(em1$pH))                    # "-" in the report
  expect_equal(em6$SpecCond, 117.7)
  # Source data errors are carried faithfully, not cleaned.
  expect_equal(em2$DO_mgL, 88.5)
})

test_that("TimeTaken is HH:MM when present, NA when blank", {
  df <- process_field_wq_domain(field_wq_xlsx(fixture_df()))$data$FieldWQ
  em1 <- df[df$Site == "EM1", ]
  em6 <- df[df$Site == "EM6", ]
  expect_match(em1$TimeTaken, "^[0-9]{2}:[0-9]{2}$")
  expect_true(is.na(em6$TimeTaken))
})

test_that("missing 'FieldWQ' sheet returns an error result", {
  tmp <- tempfile(fileext = ".xlsx")
  openxlsx::write.xlsx(list("Other" = data.frame(x = 1)), tmp)
  result <- process_field_wq_domain(tmp)
  expect_false(result$ok())
  expect_null(result$data)
  expect_equal(result$errors[[1]]$domain, "FieldWQ")
})

test_that("missing required column returns an error result", {
  df <- fixture_df(); df[["pH"]] <- NULL
  result <- process_field_wq_domain(field_wq_xlsx(df))
  expect_false(result$ok())
  expect_match(result$errors[[1]]$message, "Missing required columns")
})
