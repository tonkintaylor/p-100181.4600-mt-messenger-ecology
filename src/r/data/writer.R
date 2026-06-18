# writer.R — write assembled data frames to the output xlsx.
# Knows Excel-format details, not domain logic.

write_data_xlsx <- function(data, output_path) {
  missing <- setdiff(SHEET_ORDER, names(data))
  if (length(missing) > 0) {
    stop(sprintf("Missing required sheets: %s",
                 paste(sort(missing), collapse = ", ")))
  }
  for (sheet_name in SHEET_ORDER) {
    df <- data[[sheet_name]]
    if (nrow(df) == 0) {
      stop(sprintf("Sheet '%s' is empty - refusing to write partial output",
                   sheet_name))
    }
    expected <- SCHEMA_MAP[[sheet_name]]
    if (!identical(names(df), expected)) {
      stop(sprintf("Sheet '%s' column mismatch: expected %s, got %s",
                   sheet_name, paste(expected, collapse = ","),
                   paste(names(df), collapse = ",")))
    }
  }
  dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  ordered <- data[SHEET_ORDER]
  openxlsx::write.xlsx(ordered, file = output_path, overwrite = TRUE)
  invisible(output_path)
}
