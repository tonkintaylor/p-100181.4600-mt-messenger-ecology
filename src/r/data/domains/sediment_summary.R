# sediment_summary.R — per-site deposited-sediment + substrate summary for
# report Appendix B1 Table 3. R-only sheet (no Python counterpart).
#
# This performs NO new derivation: it simply joins the Sediment sheet (SAM1,
# SAM3) and the SedimentSize sheet (the 10 substrate fractions) on
# Site/Date/Period/Season into a single per-Site x Date row, so one sheet backs
# the appendix table. It reuses the two existing domain processors rather than
# re-reading the source, so any change to their extraction flows through.

process_sediment_summary_domain <- function(path) {
  err <- function(msg, extra = list()) DomainResult$new(
    data = NULL, errors = c(extra, list(ValidationError(
      domain = "SedimentSummary", severity = "error", file = basename(path),
      sheet = "Sediment", location = "sheet", message = msg))))

  sed <- process_sediment_domain(path)
  size <- process_sediment_size_domain(path)
  upstream <- c(sed$errors, size$errors)
  if (is.null(sed$data) || is.null(size$data)) {
    return(err("Sediment or SedimentSize domain produced no data", upstream))
  }

  keys <- c("Site", "Date", "Period", "Season")
  merged <- merge(sed$data$Sediment, size$data$SedimentSize, by = keys)
  out <- merged[order(merged$Date, merged$Site),
                SEDIMENT_SUMMARY_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(SedimentSummary = out), errors = upstream)
}
