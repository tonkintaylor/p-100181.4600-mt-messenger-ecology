# rpd.R — residual pool depth from "RPD Summary" (skip 3 header rows).

.rpd_sheet <- "RPD Summary"
.rpd_skip <- 3
.rpd_map <- c("Site" = "Site", "Date" = "Date", "Count" = "Count",
              "Mean (cm)" = "Mean", "Std Dev" = "StdDev",
              "CI Lower" = "CI_Lower", "CI Upper" = "CI_Upper")

.rpd_error <- function(path, message) {
  DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "RPD", severity = "error", file = as.character(path),
    sheet = .rpd_sheet, location = "sheet", message = message)))
}

process_rpd_domain <- function(path) {
  df <- tryCatch(readxl::read_excel(path, sheet = .rpd_sheet, skip = .rpd_skip),
                 error = function(e) e)
  if (inherits(df, "error")) {
    return(.rpd_error(path, sprintf("Sheet '%s' not found or unreadable in %s",
                                    .rpd_sheet, path)))
  }
  names(df) <- trimws(names(df))
  missing <- setdiff(names(.rpd_map), names(df))
  if (length(missing) > 0) {
    return(.rpd_error(path, sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }
  out <- df[, names(.rpd_map), drop = FALSE]
  names(out) <- unname(.rpd_map[names(out)])
  out <- out[!is.na(out$Site) & trimws(as.character(out$Site)) != "", , drop = FALSE]
  out$Date <- suppressWarnings(as.Date(out$Date))
  out$Count <- suppressWarnings(as.integer(round(as.numeric(out$Count))))
  for (col in c("Mean", "StdDev", "CI_Lower", "CI_Upper")) {
    out[[col]] <- suppressWarnings(as.numeric(out[[col]]))
  }
  out <- out[!is.na(out$Date), , drop = FALSE]
  out$Site <- as.character(out$Site)
  out <- out[, RPD_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(RPD = out))
}
