# validation.R — shared validation primitives. Each returns list(ValidationError).
# Row references are 1-based source-spreadsheet rows (data row 1 = first data row).

.first_rows <- function(idx, n = 5) {
  # idx: integer positions (1-based) of offending rows. Return first n as text.
  paste0("[", paste(utils::head(idx, n) - 1, collapse = ", "), "]")
}

# pandas' default na_values, reproduced case-sensitively (e.g. "None" -> NA but
# "none" is kept). readxl does not treat these as missing, but the Python
# pipeline that produced the golden file did, so any source column compared
# against the golden must coerce them explicitly. The source records the literal
# "N/A" in Season for surveys outside a defined monitoring season.
NA_TOKENS <- c("", "#N/A", "#N/A N/A", "#NA", "-1.#IND", "-1.#QNAN",
               "-NaN", "-nan", "1.#IND", "1.#QNAN", "<NA>", "N/A", "NA",
               "NULL", "NaN", "None", "n/a", "nan", "null")

# Locate a sheet's header row (1-based) by scanning the first `scan_rows` for one
# containing every name in `required`. Returns NA when none is found.
#
# Used by the raw per-measurement sheets instead of a hardcoded skip: inserting a
# title or note row above the header is the failure mode the fixed skips on
# "RPD Summary" (3) and "LDV Summary" (13) are prone to, and it presents as
# *every* required column being missing at once.
find_header_row <- function(path, sheet, required, scan_rows = 20L) {
  probe <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = sheet, col_names = FALSE,
                       col_types = "text", n_max = scan_rows,
                       .name_repair = "minimal"),
    error = function(e) NULL)))
  if (is.null(probe) || nrow(probe) == 0L) return(NA_integer_)
  for (i in seq_len(nrow(probe))) {
    vals <- trimws(as.character(unlist(probe[i, ], use.names = FALSE)))
    if (all(required %in% vals)) return(i)
  }
  NA_integer_
}

# Column names present on a sheet when its header is read as row 1. Used to name
# the columns actually absent when find_header_row() finds no candidate header.
header_names <- function(path, sheet) {
  probe <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = sheet, n_max = 0,
                       .name_repair = "minimal"),
    error = function(e) NULL)))
  if (is.null(probe)) character(0) else trimws(names(probe))
}

missing_cols_msg <- function(missing) {
  sprintf("Missing required columns: %s",
          paste0("[", paste(sprintf("'%s'", sort(missing)),
                            collapse = ", "), "]"))
}

check_required_columns <- function(df, expected, domain, file, sheet) {
  missing <- setdiff(expected, names(df))
  if (length(missing) == 0) return(list())
  list(ValidationError(
    domain = domain, severity = "error", file = file, sheet = sheet,
    location = "header",
    message = sprintf("Missing required columns: %s",
                      paste0("[", paste(sprintf("'%s'", sort(missing, method = "radix")),
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
  # Mirror pandas pd.to_numeric: numeric/logical columns convert directly
  # (bool -> 1/0), only genuine strings go through character coercion.
  series <- if (is.numeric(raw) || is.logical(raw)) {
    as.numeric(raw)
  } else {
    suppressWarnings(as.numeric(as.character(raw)))
  }

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
