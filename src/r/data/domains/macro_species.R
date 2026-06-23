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

  errors <- list()
  out <- list()
  for (i in seq_len(nrow(meta))) {
    m <- meta[i, ]
    sid <- as.character(m$sample_id)

    # Skip sample if its column is absent from taxa_counts
    if (!sid %in% names(bundle$taxa_counts)) {
      errors[[length(errors) + 1L]] <- err(
        sprintf("sample_col=%s", sid),
        "Sample column not found in taxa_counts",
        sev = "warning"
      )
      next
    }

    # Wrap per-sample pivot in tryCatch so unexpected errors warn and continue
    sample_rows <- tryCatch({
      counts <- bundle$taxa_counts[[sid]]
      date <- as.Date(m$Date)
      site <- trimws(as.character(m$Site))
      is_additional <- tolower(as.character(m$Season)) == "incident"
      phase <- if (!is.na(date) && date <= BASELINE_END) "Baseline" else "Construction"
      keep <- which(!is.na(counts) & counts > 0)
      lapply(keep, function(j) {
        data.frame(
          Phase = phase, Date = date, Site = site,
          Taxa = as.character(taxa_groups[j]), Species = as.character(taxa_names[j]),
          Tally = as.integer(counts[j]), is_additional = is_additional,
          stringsAsFactors = FALSE, check.names = FALSE)
      })
    }, error = function(e) {
      errors[[length(errors) + 1L]] <<- err(
        sprintf("sample_col=%s", sid),
        "Unexpected error reading sample counts",
        sev = "warning"
      )
      NULL
    })

    if (!is.null(sample_rows)) {
      out <- c(out, sample_rows)
    }
  }

  if (length(out) == 0) {
    errors[[length(errors) + 1L]] <- err("all samples", "No non-zero taxa counts found")
    return(DomainResult$new(data = NULL, errors = errors))
  }
  df <- do.call(rbind, out)[, MACRO_SPECIES_COLUMNS, drop = FALSE]
  df$Tally <- as.integer(df$Tally)
  rownames(df) <- NULL
  DomainResult$new(data = list(MacroSpecies = df), errors = errors)
}
