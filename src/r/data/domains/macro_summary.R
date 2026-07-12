# macro_summary.R — per-site macroinvertebrate summary for report Table 5.6.
# R-only sheet (no Python counterpart). Reuses ingest_raw_data() + derive_metrics().
#
# One row per Site x Date:
#   - Single-sample sites (soft-bottom / D-net, i.e. SITES_WITHOUT_REPLICATES)
#     get point estimates and NA confidence intervals, and use the soft-bottom
#     MCI/QMCI tolerance variant.
#   - Multi-sample sites (hard-bottom / Surber) get the mean across replicates
#     plus a 95% CI half-width, and use the standard MCI/QMCI variant.
# Catchment/Substrate/Method are joined from SITE_LEGEND (NA for sites absent
# from the legend, e.g. MMA 6 / MMA 6b).

# MCI / QMCI quality-class bands (Stark & Maxted 2007, NZ convention).
.macro_mci_class <- function(x) {
  if (is.na(x)) return(NA_character_)
  if (x >= 120) "Excellent" else if (x >= 100) "Good" else
    if (x >= 80) "Fair" else "Poor"
}

.macro_qmci_class <- function(x) {
  if (is.na(x)) return(NA_character_)
  if (x >= 6) "Excellent" else if (x >= 5) "Good" else
    if (x >= 4) "Fair" else "Poor"
}

# 95% CI half-width (t-based) of a numeric vector. NA when n < 2 replicates.
# Matches the table footnote "Mean +/- 95% CI calculated from five Surber samples".
# TODO(report-authors): report Table 5.6 shows NO CI on EM3's MCI even though
# every other EM3 (Surber) metric carries one -- treated here as a report
# omission (we still compute it). Confirm with the authors.
.macro_ci95 <- function(v) {
  v <- v[!is.na(v)]
  n <- length(v)
  if (n < 2) return(NA_real_)
  stats::qt(0.975, df = n - 1) * stats::sd(v) / sqrt(n)
}

.macro_mean_na <- function(v) {
  v <- v[!is.na(v)]
  if (length(v) == 0) NA_real_ else mean(v)
}

# Co-dominance ratio: the second-most-abundant taxon is reported alongside the
# most abundant only if its count is at least this fraction of the top count.
# TODO(report-authors): confirm the exact "dominant taxa" definition. Three
# rules all reproduce Table 5.6 exactly but diverge on other data -- this uses
# "two most abundant taxa, 2nd kept only if >= 50% of the most abundant".
# See tests/r/test-report-table-5-6.R for the calibration evidence.
.MACRO_DOMINANT_RATIO <- 0.50

# Taxa excluded from the report-table community indices. Koura (Paranephrops) are
# large, incidentally-caught decapods rather than part of the D-net/Surber
# macroinvertebrate community sample, so the report tables drop them from every
# metric (individuals, taxa, MCI/QMCI, % EPT, dominant taxa). Shrimp (Paratya)
# are NOT excluded (EM1 summer-2026 reproduces with its 28 Paratya included).
# This is a report-table convention ONLY: the core Macro/Macro1 pipeline (Python
# golden) keeps koura, so the exclusion is applied HERE, not in derive_metrics().
# TODO(report-authors): confirm koura exclusion. Reverse-engineered: dropping
# Paranephrops reproduces EM2 summer-2026 exactly and EM8's richness/MCI/QMCI/%EPT
# richness (EM8's individual count still differs by ~10 from the printed table --
# a residual source drift in one non-EPT taxon). Table 5.6 (spring 2025) has no
# koura, so this leaves its reproduction unchanged. See tests/r/test-report-table-5-7.R.
.MACRO_SUMMARY_EXCLUDED_TAXA <- c("Paranephrops")

process_macro_summary_domain <- function(macro_db_path) {
  file_name <- basename(macro_db_path)
  err <- function(loc, msg, sev = "error") ValidationError(
    domain = "MacroSummary", severity = sev, file = file_name,
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
  # Drop excluded taxa (koura) from every metric by zeroing their counts across
  # all sample columns before any derivation. See .MACRO_SUMMARY_EXCLUDED_TAXA.
  excl <- trimws(taxa_counts$Taxon) %in% .MACRO_SUMMARY_EXCLUDED_TAXA
  if (any(excl)) {
    sample_cols_all <- setdiff(names(taxa_counts), c("TaxonGroup", "Taxon"))
    taxa_counts[excl, sample_cols_all] <- 0L
  }
  taxa_names <- taxa_counts$Taxon
  meta$Site <- trimws(as.character(meta$Site))

  # Group replicate samples by Site x Date. "\r" is a safe separator (never a
  # site name), so paste()-keys collide only on genuine Site+Date matches.
  keys <- paste(meta$Site, as.character(as.Date(meta$Date)), sep = "\r")
  groups <- split(seq_len(nrow(meta)), keys)

  errors <- list()
  rows <- list()
  for (g in groups) {
    m0 <- meta[g[1L], ]
    site <- trimws(as.character(m0$Site))
    date <- as.Date(m0$Date)
    sb <- site %in% SITES_WITHOUT_REPLICATES
    sample_ids <- as.character(meta$sample_id[g])

    per <- lapply(sample_ids, function(sid) {
      tryCatch(derive_metrics(taxa_counts, mci_scores, sid),
               error = function(e) NULL)
    })
    per <- Filter(Negate(is.null), per)
    if (length(per) == 0L) {
      errors[[length(errors) + 1L]] <- err(
        sprintf("%s / %s", site, date),
        "No derivable metrics for Site x Date group", sev = "warning")
      next
    }

    # Pull one metric across all replicates, choosing the soft-bottom variant
    # for soft-bottom sites where one exists.
    pick <- function(std_key, sb_key = std_key) {
      k <- if (sb) sb_key else std_key
      vapply(per, function(p) as.numeric(p[[k]]), numeric(1))
    }
    num_ind <- pick("Number of Individuals")
    num_tax <- pick("Number of Taxa")
    mci     <- pick("MCI", "MCI-sb")
    qmci    <- pick("QMCI", "QMCI-sb")
    ept_r   <- pick("% EPT Richness")
    ept_a   <- pick("% EPT Abundance")

    # Dominant taxa: sum counts across replicates, keep taxa above the
    # abundance threshold, ordered by abundance descending.
    total_counts <- Reduce(`+`, lapply(sample_ids, function(sid) {
      c0 <- suppressWarnings(as.numeric(taxa_counts[[sid]]))
      c0[is.na(c0)] <- 0
      c0
    }))
    tot <- sum(total_counts)
    dominant <- if (tot > 0) {
      ord <- order(total_counts, decreasing = TRUE)
      keep <- ord[1L]
      if (length(ord) >= 2L &&
          total_counts[ord[2L]] >= .MACRO_DOMINANT_RATIO * total_counts[ord[1L]]) {
        keep <- c(keep, ord[2L])
      }
      paste(taxa_names[keep], collapse = ", ")
    } else NA_character_

    mci_v <- .macro_mean_na(mci)
    qmci_v <- .macro_mean_na(qmci)
    rows[[length(rows) + 1L]] <- data.frame(
      Site = site, Date = date,
      Season = normalise_season(trimws(as.character(m0$Season)), date),
      Year = as.integer(format(date, "%Y")),
      NumIndividuals = .macro_mean_na(num_ind),
      NumIndividuals_CI = .macro_ci95(num_ind),
      NumTaxa = .macro_mean_na(num_tax), NumTaxa_CI = .macro_ci95(num_tax),
      MCI = mci_v, MCI_CI = .macro_ci95(mci), MCI_Class = .macro_mci_class(mci_v),
      QMCI = qmci_v, QMCI_CI = .macro_ci95(qmci),
      QMCI_Class = .macro_qmci_class(qmci_v),
      PctEPTRichness = .macro_mean_na(ept_r),
      PctEPTRichness_CI = .macro_ci95(ept_r),
      PctEPTAbundance = .macro_mean_na(ept_a),
      PctEPTAbundance_CI = .macro_ci95(ept_a),
      DominantTaxa = dominant,
      stringsAsFactors = FALSE, check.names = FALSE)
  }

  if (length(rows) == 0L) {
    return(DomainResult$new(data = NULL, errors = c(errors, list(
      err("data", "No sample data could be summarised")))))
  }

  df <- do.call(rbind, rows)
  # Join static site attributes; all.x keeps sites absent from the legend.
  df <- merge(df, SITE_LEGEND[, c("Site", "Catchment", "Substrate", "Method")],
              by = "Site", all.x = TRUE, sort = FALSE)
  df <- df[order(df$Date, df$Site), MACRO_SUMMARY_COLUMNS, drop = FALSE]
  rownames(df) <- NULL
  DomainResult$new(data = list(MacroSummary = df), errors = errors)
}
