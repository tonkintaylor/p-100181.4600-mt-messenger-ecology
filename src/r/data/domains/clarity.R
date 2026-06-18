# clarity.R — water clarity from the Aquatic Monitoring Database "Clarity Data".

.clarity_source_sheet <- "Clarity Data"
.clarity_required <- c("Site", "Date", "Clarity (mm)")
.clarity_renames <- c("NTU-Continous Sensor" = "NTU-Continuous Sensor")

.clarity_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "Clarity", severity = "error", file = as.character(path),
    sheet = .clarity_source_sheet, location = "sheet", message = message)))
}

process_clarity_domain <- function(path) {
  df <- tryCatch(
    readxl::read_excel(path, sheet = .clarity_source_sheet),
    error = function(e) e)
  if (inherits(df, "error")) {
    return(.clarity_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                        .clarity_source_sheet, path)))
  }
  names(df) <- trimws(names(df))
  for (old in names(.clarity_renames)) {
    if (old %in% names(df)) names(df)[names(df) == old] <- .clarity_renames[[old]]
  }
  missing <- setdiff(.clarity_required, names(df))
  if (length(missing) > 0) {
    return(.clarity_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }

  n <- nrow(df)
  coerce <- function(col) {
    if (col == "Date") return(as.Date(df[[col]]))
    if (!col %in% names(df)) {
      return(if (col == "Comments") rep(NA_character_, n) else rep(NA_real_, n))
    }
    if (col == "Comments" || col == "Site") return(as.character(df[[col]]))
    v <- df[[col]]
    if (!is.numeric(v)) v <- gsub(" ", "", trimws(as.character(v)))
    suppressWarnings(as.numeric(v))
  }
  out <- as.data.frame(setNames(lapply(CLARITY_COLUMNS, coerce), CLARITY_COLUMNS),
                       stringsAsFactors = FALSE, check.names = FALSE)
  DomainResult$new(data = list(Clarity = out))
}
