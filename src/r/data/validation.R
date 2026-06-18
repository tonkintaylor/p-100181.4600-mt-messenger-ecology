# validation.R — shared validation primitives. Each returns list(ValidationError).
# Row references are 1-based source-spreadsheet rows (data row 1 = first data row).

.first_rows <- function(idx, n = 5) {
  # idx: integer positions (1-based) of offending rows. Return first n as text.
  paste0("[", paste(utils::head(idx, n) - 1, collapse = ", "), "]")
}

check_required_columns <- function(df, expected, domain, file, sheet) {
  missing <- setdiff(expected, names(df))
  if (length(missing) == 0) return(list())
  list(ValidationError(
    domain = domain, severity = "error", file = file, sheet = sheet,
    location = "header",
    message = sprintf("Missing required columns: %s",
                      paste0("[", paste(sprintf("'%s'", sort(missing)),
                                        collapse = ", "), "]"))
  ))
}

check_no_nulls <- function(df, columns, domain, file, sheet) {
  errs <- list()
  for (col in columns) {
    if (!col %in% names(df)) next
    null_mask <- is.na(df[[col]])
    if (any(null_mask)) {
      rows <- which(null_mask)
      errs <- c(errs, list(ValidationError(
        domain = domain, severity = "error", file = file, sheet = sheet,
        location = sprintf("column '%s', rows %s", col, .first_rows(rows)),
        message = sprintf("Found %d null values in required column '%s'",
                          sum(null_mask), col)
      )))
    }
  }
  errs
}

check_value_range <- function(df, column, min_val = NULL, max_val = NULL,
                              domain, file, sheet) {
  errs <- list()
  if (!column %in% names(df)) return(errs)
  raw <- df[[column]]
  series <- suppressWarnings(as.numeric(as.character(raw)))

  coerced_nans <- is.na(series) & !is.na(raw)
  if (any(coerced_nans)) {
    rows <- which(coerced_nans)
    errs <- c(errs, list(ValidationError(
      domain = domain, severity = "error", file = file, sheet = sheet,
      location = sprintf("column '%s', rows %s", column, .first_rows(rows)),
      message = sprintf("Found %d non-numeric values in column '%s'",
                        sum(coerced_nans), column)
    )))
  }
  if (!is.null(min_val)) {
    below <- !is.na(series) & series < min_val
    if (any(below)) {
      errs <- c(errs, list(ValidationError(
        domain = domain, severity = "error", file = file, sheet = sheet,
        location = sprintf("column '%s', rows %s", column, .first_rows(which(below))),
        message = sprintf("Values below minimum %s in column '%s'", min_val, column)
      )))
    }
  }
  if (!is.null(max_val)) {
    above <- !is.na(series) & series > max_val
    if (any(above)) {
      errs <- c(errs, list(ValidationError(
        domain = domain, severity = "error", file = file, sheet = sheet,
        location = sprintf("column '%s', rows %s", column, .first_rows(which(above))),
        message = sprintf("Values above maximum %s in column '%s'", max_val, column)
      )))
    }
  }
  errs
}
