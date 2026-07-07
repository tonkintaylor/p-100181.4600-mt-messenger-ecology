# fish_summary.R — per-site freshwater fish summary for report Table 5.8.
# R-only sheet (no Python counterpart). Reads the raw "Fish Trapping" sheet
# (species-level, with Method/Net-Trap effort) that the Fish sheet collapses
# away, and produces one row per Catchment x Site x Season x Year.
#
# TotalFish excludes koura and shrimp but includes unidentified fish/eels.
# TaxaRichness counts distinct identified taxa groups present (koura counts,
# shrimp excluded, unidentified not counted separately -- report footnotes).
# CPUE = catch (excl. koura & shrimp) per net/trap, separately for mini-fyke
# nets (Fyke) and Gee's minnow traps (GMT).
#
# TODO(report-authors): (1) confirm the "taxa groups" used for TaxaRichness
# (report Section 5.2.9) -- implemented here as distinct identified species
# present; (2) confirm the species->row mapping for "elver" and "unidentified
# galaxiid" (mapped to Unid. eel / Unid. kokopu here). See
# tests/r/test-report-table-5-8.R for calibration evidence.

.fish_summary_sheet <- "Fish Trapping"

# Source Species (lowercased) -> summary column. Unmapped species (e.g. shrimp,
# "no catch") contribute to neither counts nor totals.
.FISH_SPECIES_MAP <- c(
  "longfin eel"           = "LongfinEel",
  "shortfin eel"          = "ShortfinEel",
  "elver"                 = "UnidEel",
  "unidentified eel"      = "UnidEel",
  "common bully"          = "CommonBully",
  "redfin bully"          = "RedfinBully",
  "unidentified bully"    = "UnidBully",
  "banded kokopu"         = "BandedKokopu",
  "giant kokopu"          = "GiantKokopu",
  "unidentified kokopu"   = "UnidKokopu",
  "unidentified galaxiid" = "UnidKokopu",
  "inanga"                = "Inanga",
  "koura"                 = "Koura"
)

.FISH_SPECIES_COLS <- c("LongfinEel", "ShortfinEel", "CommonBully", "RedfinBully",
                        "BandedKokopu", "GiantKokopu", "Inanga",
                        "UnidBully", "UnidKokopu", "UnidEel", "Koura")

# Fish counted toward TotalFish and CPUE: everything except koura (and shrimp,
# which is never mapped). Includes unidentified fish/eels.
.FISH_TOTAL_COLS <- setdiff(.FISH_SPECIES_COLS, "Koura")

# Identified taxa groups for richness (no unidentified; koura counts).
.FISH_RICHNESS_COLS <- c("LongfinEel", "ShortfinEel", "CommonBully", "RedfinBully",
                         "BandedKokopu", "GiantKokopu", "Inanga", "Koura")

# Shrimp abundance is qualitative per net/trap; collapse to one value per group
# by the mean of the abundance ranks (rounded). Ranks: Uncommon<Common<Abundant.
.FISH_SHRIMP_RANK <- c(U = 1, C = 2, A = 3)
.FISH_SHRIMP_LABEL <- c("Uncommon", "Common", "Abundant")  # indexed by rank

# CPUE effort: fixed deployment protocol per site (mini-fyke nets and Gee's
# minnow traps). The report divides by nets DEPLOYED, not nets that recorded a
# catch, so a net that caught nothing (and left no row) still counts.
# TODO(report-authors): confirm the deployed effort (6 fykes / 12 GMTs) and
# whether it is constant across all monitoring cycles (only 2025-2026 verified).
.FISH_EFFORT <- c(Fyke = 6, GMT = 12)

process_fish_summary_domain <- function(path) {
  err <- function(msg) DomainResult$new(data = NULL, errors = list(ValidationError(
    domain = "FishSummary", severity = "error", file = basename(path),
    sheet = .fish_summary_sheet, location = "sheet", message = msg)))

  df <- suppressWarnings(suppressMessages(tryCatch(
    readxl::read_excel(path, sheet = .fish_summary_sheet),
    error = function(e) e)))
  if (inherits(df, "error")) {
    return(err(sprintf("Sheet '%s' not found or unreadable in %s",
                       .fish_summary_sheet, path)))
  }
  names(df) <- trimws(names(df))
  req <- c("Season", "Date", "Catchment", "Site", "Method", "Net/Trap #",
           "Species", "Number", "Shrimp abundance")
  missing <- setdiff(req, names(df))
  if (length(missing) > 0) {
    return(err(sprintf("Missing required columns: %s",
      paste0("[", paste(sprintf("'%s'", sort(missing)), collapse = ", "), "]"))))
  }

  sp <- tolower(trimws(as.character(df$Species)))
  col <- unname(.FISH_SPECIES_MAP[sp])
  num <- suppressWarnings(as.numeric(df$Number)); num[is.na(num)] <- 0
  season <- trimws(as.character(df$Season))
  year <- suppressWarnings(as.integer(as.numeric(as.character(df$Date))))
  site <- trimws(as.character(df$Site))
  catchment <- trimws(as.character(df$Catchment))
  method <- trimws(as.character(df$Method))
  net <- trimws(as.character(df[["Net/Trap #"]]))
  shrimp_ab <- toupper(trimws(as.character(df[["Shrimp abundance"]])))

  key <- paste(catchment, site, season, year, sep = "\r")
  groups <- split(seq_len(nrow(df)), key)

  rows <- lapply(groups, function(g) {
    gcol <- col[g]; gnum <- num[g]; gmethod <- method[g]
    counts <- vapply(.FISH_SPECIES_COLS,
                     function(cc) sum(gnum[!is.na(gcol) & gcol == cc]), numeric(1))
    total <- sum(counts[.FISH_TOTAL_COLS])
    richness <- sum(counts[.FISH_RICHNESS_COLS] > 0)

    is_total <- !is.na(gcol) & gcol %in% .FISH_TOTAL_COLS
    cpue <- function(m) {
      sel <- gmethod == m
      if (!any(sel)) return(NA_real_)
      sum(gnum[sel & is_total]) / .FISH_EFFORT[[m]]
    }

    ranks <- .FISH_SHRIMP_RANK[shrimp_ab[g]]
    ranks <- ranks[!is.na(ranks)]
    shrimp <- if (length(ranks) == 0L) "" else
      .FISH_SHRIMP_LABEL[floor(mean(ranks) + 0.5)]

    base <- data.frame(
      Catchment = catchment[g[1L]], Site = site[g[1L]],
      Season = season[g[1L]], Year = year[g[1L]],
      check.names = FALSE, stringsAsFactors = FALSE)
    cnt <- as.data.frame(as.list(counts), check.names = FALSE)
    tail <- data.frame(
      Shrimp = shrimp, TotalFish = total, TaxaRichness = as.integer(richness),
      CPUE_fykes = cpue("Fyke"), CPUE_GMTs = cpue("GMT"),
      check.names = FALSE, stringsAsFactors = FALSE)
    cbind(base, cnt, tail)
  })

  out <- do.call(rbind, rows)
  out <- out[order(out$Year, out$Season, out$Catchment, out$Site),
             FISH_SUMMARY_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(FishSummary = out))
}
