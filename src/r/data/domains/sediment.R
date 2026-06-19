# sediment.R — Sediment domain: SAM score extraction from the Aquatic Monitoring Database.

process_sediment_domain <- function(path) {
  df <- tryCatch(read_sediment_sheet(path),
                 error = function(e) return(NULL))
  if (is.null(df)) {
    return(sediment_make_error("Sediment", path, "Failed to read Sediment sheet"))
  }
  for (col in c(SOURCE_SAM1_COL, SOURCE_SAM3_COL)) {
    if (!col %in% names(df)) {
      return(sediment_make_error("Sediment", path,
        sprintf("Missing required column: '%s'", col)))
    }
  }
  out <- data.frame(
    Site   = df$Site,
    Date   = df$Date,
    Period = df$Period,
    SAM1   = suppressWarnings(as.numeric(df[[SOURCE_SAM1_COL]])),
    SAM3   = suppressWarnings(as.numeric(df[[SOURCE_SAM3_COL]])),
    Season = df$Season,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  out <- out[, SEDIMENT_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(Sediment = out))
}
