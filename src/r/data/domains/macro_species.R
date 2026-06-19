# macro_species.R — pivot taxa counts to sparse long format.

process_macro_species_domain <- function(macro_db_path) {
  file_name <- basename(macro_db_path)
  err <- function(loc, msg, sev = "error") ValidationError(
    domain = "MacroSpecies", severity = sev, file = file_name,
    sheet = "RawData", location = loc, message = msg)

  bundle <- tryCatch(ingest_raw_data(macro_db_path), error = function(e) e)
  if (inherits(bundle, "error")) {
    return(DomainResult$new(data = NULL, errors = list(
      err("file", sprintf("Failed to read RawData: %s", conditionMessage(bundle))))))
  }
  meta <- bundle$sample_metadata
  taxa_groups <- bundle$taxa_counts$TaxonGroup
  taxa_names <- bundle$taxa_counts$Taxon

  out <- list()
  for (i in seq_len(nrow(meta))) {
    m <- meta[i, ]
    sid <- as.character(m$sample_id)
    counts <- bundle$taxa_counts[[sid]]
    date <- as.Date(m$Date)
    site <- trimws(as.character(m$Site))
    is_additional <- tolower(as.character(m$Season)) == "incident"
    phase <- if (!is.na(date) && date <= BASELINE_END) "Baseline" else "Construction"
    keep <- which(!is.na(counts) & counts > 0)
    for (j in keep) {
      out[[length(out) + 1L]] <- data.frame(
        Phase = phase, Date = date, Site = site,
        Taxa = as.character(taxa_groups[j]), Species = as.character(taxa_names[j]),
        Tally = as.integer(counts[j]), is_additional = is_additional,
        stringsAsFactors = FALSE, check.names = FALSE)
    }
  }
  if (length(out) == 0) {
    return(DomainResult$new(data = NULL, errors = list(
      err("all samples", "No non-zero taxa counts found"))))
  }
  df <- do.call(rbind, out)[, MACRO_SPECIES_COLUMNS, drop = FALSE]
  df$Tally <- as.integer(df$Tally)
  rownames(df) <- NULL
  DomainResult$new(data = list(MacroSpecies = df))
}
