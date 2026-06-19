# macro.R — macroinvertebrate metric derivation + Macro1/Macro assembly.

.EPT_GROUPS <- c("Mayflies", "Stoneflies", "Caddisflies")
.HYDROPTILIDAE_GENERA <- c("Oxyethira", "Paroxyethira")
.ASPM_MCI_MAX <- 200
.ASPM_EPT_RICHNESS_MAX <- 29
.ASPM_EPT_ABUNDANCE_MAX <- 100
.PERIOD_MAP <- c("Baseline" = "Baseline", "Construction" = "Routine Construction",
                 "Additional" = "Incident")
.SPRING_MONTHS <- c(10, 11, 12)

derive_metrics <- function(taxa_counts, mci_scores, sample_col) {
  key <- as.character(sample_col)
  merged <- merge(
    taxa_counts[, c("TaxonGroup", "Taxon", key)],
    mci_scores, by = "Taxon", all.x = TRUE, sort = FALSE)
  counts <- merged[[key]]; counts[is.na(counts)] <- 0; counts <- as.numeric(counts)
  present <- counts > 0

  num_taxa <- sum(present)
  num_individuals <- sum(counts)

  mci_vals <- merged$MCI[present]; mci_vals <- mci_vals[!is.na(mci_vals)]
  mci <- if (length(mci_vals) > 0) sum(mci_vals) / length(mci_vals) * 20 else NA_real_
  mci_sb_vals <- merged$MCI_sb[present]; mci_sb_vals <- mci_sb_vals[!is.na(mci_sb_vals)]
  mci_sb <- if (length(mci_sb_vals) > 0) sum(mci_sb_vals)/length(mci_sb_vals)*20 else NA_real_

  mci0 <- merged$MCI; mci0[is.na(mci0)] <- 0
  mci_sb0 <- merged$MCI_sb; mci_sb0[is.na(mci_sb0)] <- 0
  qmci <- if (num_individuals > 0) sum(counts * mci0) / num_individuals else NA_real_
  qmci_sb <- if (num_individuals > 0) sum(counts * mci_sb0) / num_individuals else NA_real_

  is_ept <- merged$TaxonGroup %in% .EPT_GROUPS
  is_e <- merged$TaxonGroup == "Mayflies"
  is_p <- merged$TaxonGroup == "Stoneflies"
  is_t <- is_ept & !is_e & !is_p
  is_hydro <- trimws(merged$Taxon) %in% .HYDROPTILIDAE_GENERA
  is_t_excl <- is_t & !is_hydro

  e_rich <- sum(counts[is_e] > 0)
  p_rich <- sum(counts[is_p] > 0)
  t_rich <- sum(counts[is_t_excl] > 0)
  ept_rich <- e_rich + p_rich + t_rich
  ept_abun <- sum(counts[is_e | is_p | is_t_excl])

  pct_ept_abun <- if (num_individuals > 0) ept_abun / num_individuals else NA_real_
  pct_ept_rich <- if (num_taxa > 0) ept_rich / num_taxa else NA_real_
  aspm_mci <- if (!is.na(mci)) mean(c(mci/.ASPM_MCI_MAX,
    ept_rich/.ASPM_EPT_RICHNESS_MAX, ept_abun/.ASPM_EPT_ABUNDANCE_MAX)) else NA_real_

  list(`Number of Taxa` = as.integer(num_taxa),
       `Number of Individuals` = as.integer(num_individuals),
       MCI = mci, `MCI-sb` = mci_sb, QMCI = qmci, `QMCI-sb` = qmci_sb,
       `EPT Abundance` = as.integer(ept_abun),
       `E Richness` = as.integer(e_rich), `P Richness` = as.integer(p_rich),
       `T Richness` = as.integer(t_rich), `EPT Richness` = as.integer(ept_rich),
       `% EPT Abundance` = pct_ept_abun, `% EPT Richness` = pct_ept_rich,
       `ASPM-MCI` = aspm_mci)
}

normalise_period <- function(raw_season, date) {
  d <- as.Date(date)
  if (!is.na(d) && d <= BASELINE_END) return("Baseline")
  p <- .PERIOD_MAP[raw_season]
  if (is.na(p)) return("Routine Construction")
  unname(p)
}

normalise_season <- function(raw_season, date) {
  if (identical(raw_season, "Additional")) return("incident response")
  m <- as.integer(format(as.Date(date), "%m"))
  if (m %in% .SPRING_MONTHS) "Spring" else "Summer"
}

.macro_error <- function(file_name, sheet, location, message, severity = "error") {
  ValidationError(domain = "macroinvertebrate", severity = severity,
                  file = file_name, sheet = sheet, location = location,
                  message = message)
}

process_macro_domain <- function(macro_db_path) {
  file_name <- basename(macro_db_path)
  errors <- list()
  bundle <- tryCatch(ingest_raw_data(macro_db_path),
    error = function(e) e)
  if (inherits(bundle, "error")) {
    return(DomainResult$new(data = NULL, errors = list(.macro_error(
      file_name, "RawData", "file",
      sprintf("Failed to read RawData: %s", conditionMessage(bundle))))))
  }
  meta <- bundle$sample_metadata
  rows <- list()
  for (i in seq_len(nrow(meta))) {
    m <- meta[i, ]
    sid <- as.character(m$sample_id)
    metrics <- tryCatch(derive_metrics(bundle$taxa_counts, bundle$mci_scores, sid),
      error = function(e) e)
    if (inherits(metrics, "error")) {
      errors <- c(errors, list(.macro_error(file_name, "RawData",
        sprintf("sample_col=%s", sid),
        sprintf("Failed to derive metrics: %s", conditionMessage(metrics)),
        severity = "warning")))
      next
    }
    site <- trimws(as.character(m$Site))
    qmci_value <- if (site %in% SITES_WITHOUT_REPLICATES) metrics[["QMCI-sb"]] else metrics[["QMCI"]]
    raw_season <- trimws(as.character(m$Season))
    rows[[length(rows) + 1L]] <- data.frame(
      Site = site, Date = as.Date(m$Date),
      Period = normalise_period(raw_season, m$Date),
      EPTrich = metrics[["% EPT Richness"]],
      EPTabun = metrics[["% EPT Abundance"]],
      QMCI = qmci_value,
      Season = normalise_season(raw_season, m$Date),
      stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (length(rows) == 0) {
    return(DomainResult$new(data = NULL, errors = c(errors, list(.macro_error(
      file_name, "RawData", "data", "No sample data could be processed")))))
  }
  macro1 <- do.call(rbind, rows)[, MACRO1_COLUMNS, drop = FALSE]
  rownames(macro1) <- NULL

  replicated <- macro1[!(macro1$Site %in% SITES_WITHOUT_REPLICATES), , drop = FALSE]
  agg <- stats::aggregate(
    cbind(EPTrich, EPTabun, QMCI) ~ Site + Date + Period + Season,
    data = replicated, FUN = mean, na.action = stats::na.pass)
  macro <- agg[, MACRO1_COLUMNS, drop = FALSE]
  rownames(macro) <- NULL

  DomainResult$new(data = list(Macro1 = macro1, Macro = macro), errors = errors)
}
