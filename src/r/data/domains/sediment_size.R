# sediment_size.R — SedimentSize domain: grain-size distribution.
#
# Reads the Sediment sheet via read_sediment_sheet() and produces the
# SedimentSize output data frame with SEDIMENT_SIZE_COLUMNS column order.

process_sediment_size_domain <- function(path) {
  df <- tryCatch(read_sediment_sheet(path), error = function(e) return(NULL))
  if (is.null(df)) {
    return(sediment_make_error("SedimentSize", path, "Failed to read Sediment sheet"))
  }
  missing_grain <- setdiff(GRAIN_SIZE_SOURCE_COLUMNS, names(df))
  if (length(missing_grain) > 0) {
    return(sediment_make_error("SedimentSize", path,
      sprintf("Missing grain-size columns: %s",
        paste0("[", paste(sprintf("'%s'", missing_grain), collapse = ", "), "]"))))
  }
  out <- data.frame(Site = df$Site, Date = df$Date, Period = df$Period,
                    Season = df$Season, stringsAsFactors = FALSE, check.names = FALSE)
  for (col in GRAIN_SIZE_SOURCE_COLUMNS) {
    out[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  }
  out <- out[, SEDIMENT_SIZE_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(SedimentSize = out))
}
