# macro_sample.R — raw macroinvertebrate count matrix for report Appendix B2
# Tables 1 & 2 (Spring 2025, Summer 2026). R-only sheet (no Python counterpart).
#
# One row per Season x Site x Replicate x Taxon with a non-zero count. Unlike
# MacroSpecies this keeps the Replicate number (1-5 for Surber sites, NA for
# single-sample soft-bottom sites) and the taxon's MCI / MCI-sb tolerance
# scores. A faithful tidy emission of ingest_raw_data(); no derivation beyond
# the Season label (via normalise_season) and the count > 0 filter.

process_macro_sample_domain <- function(macro_db_path) {
  file_name <- basename(macro_db_path)
  err <- function(loc, msg, sev = "error") ValidationError(
    domain = "MacroSampleData", severity = sev, file = file_name,
    sheet = "RawData", location = loc, message = msg)

  bundle <- tryCatch(ingest_raw_data(macro_db_path), error = function(e) e)
  if (inherits(bundle, "error")) {
    return(DomainResult$new(data = NULL, errors = list(
      err("file", sprintf("Failed to read RawData: %s",
                          conditionMessage(bundle))))))
  }
  meta <- bundle$sample_metadata
  taxa_counts <- bundle$taxa_counts
  mci_scores <- bundle$mci_scores
  # taxa_counts and mci_scores share the same row order (both from the taxa
  # block), so tolerance scores align positionally with the taxon rows.
  taxa_groups <- trimws(as.character(taxa_counts$TaxonGroup))
  species <- trimws(as.character(taxa_counts$Taxon))
  mci <- mci_scores$MCI
  mci_sb <- mci_scores$MCI_sb

  errors <- list()
  out <- list()
  for (i in seq_len(nrow(meta))) {
    m <- meta[i, ]
    sid <- as.character(m$sample_id)
    if (!sid %in% names(taxa_counts)) {
      errors[[length(errors) + 1L]] <- err(
        sprintf("sample_col=%s", sid),
        "Sample column not found in taxa_counts", sev = "warning")
      next
    }
    rows <- tryCatch({
      counts <- taxa_counts[[sid]]
      date <- as.Date(m$Date)
      site <- trimws(as.character(m$Site))
      season <- normalise_season(trimws(as.character(m$Season)), date)
      year <- as.integer(format(date, "%Y"))
      rep_no <- suppressWarnings(as.integer(m$Replicate))
      keep <- which(!is.na(counts) & counts > 0)
      lapply(keep, function(j) data.frame(
        Season = season, Year = year, Date = date, Site = site,
        Replicate = rep_no, TaxaGroup = taxa_groups[j], Species = species[j],
        MCI = mci[j], MCI_sb = mci_sb[j], Count = as.integer(counts[j]),
        stringsAsFactors = FALSE, check.names = FALSE))
    }, error = function(e) {
      errors[[length(errors) + 1L]] <<- err(sprintf("sample_col=%s", sid),
        "Unexpected error reading sample counts", sev = "warning")
      NULL
    })
    if (!is.null(rows)) out <- c(out, rows)
  }

  if (length(out) == 0) {
    return(DomainResult$new(data = NULL, errors = c(errors, list(
      err("all samples", "No non-zero taxa counts found")))))
  }
  df <- do.call(rbind, out)[, MACRO_SAMPLE_COLUMNS, drop = FALSE]
  df <- df[order(df$Date, df$Site, df$Replicate, df$TaxaGroup, df$Species), ,
           drop = FALSE]
  rownames(df) <- NULL
  DomainResult$new(data = list(MacroSampleData = df), errors = errors)
}
