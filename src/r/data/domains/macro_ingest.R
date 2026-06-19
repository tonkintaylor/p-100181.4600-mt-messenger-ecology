# macro_ingest.R — ACL for the Macroinvertebrate Database "RawData" sheet.
# Column indices are 1-based here; Python uses 0-based (_DATA_COL_START=4 -> 5).
#
# RawData layout (1-indexed as seen in Excel):
#   Row 1: QA Note flags (informational)
#   Row 2: Season label (Baseline / Construction / Additional / Routine)
#   Row 3: Date
#   Row 4: Site (EM1, EM2, ..., MMA 6, MMA 6b)
#   Row 5: Replicate (1-5 or blank for unreplicated site-dates)
#   Rows 6+: Taxa counts, then derived metrics separated by the marker row
#   Columns A-B: TaxonGroup, Taxon (scientific name)
#   Columns C-D: MCI tolerance value, MCI-sb tolerance value
#   Columns E onward: Sample data (one col per site x date x replicate)

.macro_metrics_marker <- "Number of Taxa"
.macro_header_rows    <- 5L
.macro_data_col_start <- 5L  # 1-based: A=1,B=2,C=3,D=4,E=5

#' Signal an ingest error condition
#'
#' @param msg Character string describing the error.
ingest_error <- function(msg) {
  stop(structure(
    class = c("ingest_error", "error", "condition"),
    list(message = msg, call = NULL)
  ))
}

#' Parse the RawData sheet into clean internal components.
#'
#' This is the ONLY place that knows about the messy multi-row header format.
#' All downstream domain modules receive clean data frames.
#'
#' @param macro_db_path Path to the Macroinvertebrate Database Excel file.
#' @return A named list with:
#'   \describe{
#'     \item{sample_metadata}{data.frame: sample_id, Season, Date, Site, Replicate}
#'     \item{taxa_counts}{data.frame: TaxonGroup, Taxon, then one integer col per sample}
#'     \item{metric_rows}{data.frame: Metric, then one numeric col per sample}
#'     \item{mci_scores}{data.frame: Taxon, MCI, MCI_sb (numeric)}
#'   }
#' @export
ingest_raw_data <- function(macro_db_path) {
  raw <- tryCatch(
    readxl::read_excel(macro_db_path, sheet = "RawData",
                       col_names = FALSE, col_types = "text"),
    error = function(e) ingest_error(
      sprintf("Cannot read 'RawData' sheet from %s: %s",
              macro_db_path, conditionMessage(e))
    )
  )
  raw <- as.data.frame(raw, stringsAsFactors = FALSE, check.names = FALSE)
  ncol_raw  <- ncol(raw)
  sample_cols <- seq.int(.macro_data_col_start, ncol_raw)  # 1-based indices

  # --- sample metadata from rows 2..5 (Season, Date, Site, Replicate) ---
  hdr <- function(r) unlist(raw[r, sample_cols], use.names = FALSE)

  date_raw <- hdr(3)
  # Try Excel serial first; cells that come back NA are text dates.
  parsed_dates <- suppressWarnings(
    as.Date(as.numeric(date_raw), origin = "1899-12-30")
  )
  bad_date <- is.na(parsed_dates)
  if (any(bad_date)) {
    parsed_dates[bad_date] <- suppressWarnings(as.Date(date_raw[bad_date]))
  }

  meta <- data.frame(
    sample_id = sample_cols,
    Season    = as.character(hdr(2)),
    Date      = parsed_dates,
    Site      = trimws(as.character(hdr(4))),
    Replicate = suppressWarnings(as.integer(round(as.numeric(hdr(5))))),
    stringsAsFactors = FALSE
  )

  # --- split data rows at the metrics marker ---
  data_block <- raw[(.macro_header_rows + 1L):nrow(raw), , drop = FALSE]
  rownames(data_block) <- NULL

  col_b  <- trimws(as.character(data_block[[2]]))
  marker <- which(col_b == .macro_metrics_marker)
  if (length(marker) == 0L) {
    ingest_error(paste0(
      "'", .macro_metrics_marker,
      "' marker not found in column B. The RawData sheet structure may have changed."
    ))
  }
  split_at     <- marker[1L]
  taxa_block   <- data_block[seq_len(split_at - 1L), , drop = FALSE]
  metric_block <- data_block[split_at:nrow(data_block), , drop = FALSE]

  # --- taxa counts: TaxonGroup, Taxon, then one integer column per sample ---
  taxa_counts <- data.frame(
    TaxonGroup = as.character(taxa_block[[1]]),
    Taxon      = as.character(taxa_block[[2]]),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  for (ci in sample_cols) {
    taxa_counts[[as.character(ci)]] <-
      suppressWarnings(as.integer(round(as.numeric(taxa_block[[ci]]))))
  }

  # --- MCI tolerance scores from cols C (3) and D (4) ---
  mci_scores <- data.frame(
    Taxon  = as.character(taxa_block[[2]]),
    MCI    = suppressWarnings(as.numeric(taxa_block[[3]])),
    MCI_sb = suppressWarnings(as.numeric(taxa_block[[4]])),
    stringsAsFactors = FALSE, check.names = FALSE
  )

  # --- metric rows ---
  metric_rows <- data.frame(
    Metric = trimws(as.character(metric_block[[2]])),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  for (ci in sample_cols) {
    metric_rows[[as.character(ci)]] <-
      suppressWarnings(as.numeric(metric_block[[ci]]))
  }

  list(
    sample_metadata = meta,
    taxa_counts     = taxa_counts,
    metric_rows     = metric_rows,
    mci_scores      = mci_scores
  )
}
