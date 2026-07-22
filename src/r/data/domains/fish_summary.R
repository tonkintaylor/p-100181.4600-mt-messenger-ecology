# fish_summary.R — per-site freshwater fish summary for report Table 5.8.
# R-only sheet (no Python counterpart). Reads the raw "Fish Trapping" sheet
# (species-level, with Method/Net-Trap effort) that the Fish sheet collapses
# away, and produces one row per Catchment x Site x Season x Year.
#
# TotalFish excludes koura and shrimp but includes unidentified fish/eels.
# TaxaRichness counts distinct taxa GROUPS present (author-confirmed rule): eel,
# bully and kokopu each collapse to a single taxon regardless of how many of
# their species -- including unidentified -- occur; Inanga, koura and shrimp
# each count once. NOTE: this deliberately diverges from the printed Table 5.8,
# which excluded shrimp; the report author confirmed the group-based rule
# (incl. shrimp and grouped eels) in the 2026 regeneration review.
# CPUE = catch (excl. koura & shrimp) per net/trap actually deployed (count of
# distinct Net/Trap # recorded for the method; empty nets recorded as "no catch"
# rows still count), separately for mini-fyke nets (Fyke) and Gee's minnow traps
# (GMT). Author-confirmed (2026 regeneration review): count-based, not fixed.
#
# Species->row mapping author-confirmed (2026 review): "elver" -> Unid. eel
# (eels grouped); "unidentified galaxiid" is a SEPARATE row (UnidGalaxiid), NOT
# folded into Unid. kokopu, and is excluded from taxa richness. See
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
  "unidentified galaxiid" = "UnidGalaxiid",
  "inanga"                = "Inanga",
  "koura"                 = "Koura"
)

.FISH_SPECIES_COLS <- c("LongfinEel", "ShortfinEel", "CommonBully", "RedfinBully",
                        "BandedKokopu", "GiantKokopu", "Inanga",
                        "UnidBully", "UnidKokopu", "UnidGalaxiid", "UnidEel",
                        "Koura")

# Fish counted toward TotalFish and CPUE: everything except koura (and shrimp,
# which is never mapped). Includes unidentified fish/eels.
.FISH_TOTAL_COLS <- setdiff(.FISH_SPECIES_COLS, "Koura")

# Taxa GROUPS for richness (author-confirmed): each group counts once if any of
# its species is present. Eel = longfin/shortfin/unidentified(+elver); bully =
# common/redfin/unidentified; kokopu = banded/giant/unidentified kokopu; plus
# Inanga and Koura. Shrimp is counted separately (presence from the "Shrimp
# abundance" field, not a species count). "Unidentified galaxiid" is DELIBERATELY
# absent: the author keeps it a separate row but excludes it from richness (not
# all galaxiids are kokopu, and it can't be counted as its own identified taxon).
.FISH_RICHNESS_GROUPS <- list(
  Eel    = c("LongfinEel", "ShortfinEel", "UnidEel"),
  Bully  = c("CommonBully", "RedfinBully", "UnidBully"),
  Kokopu = c("BandedKokopu", "GiantKokopu", "UnidKokopu"),
  Inanga = "Inanga",
  Koura  = "Koura"
)

# Shrimp abundance is qualitative per net/trap; collapse to one value per site
# by the mean of the abundance ranks (rounded) -- author-confirmed (2026
# regeneration review) over the "most frequent category" wording in Section
# 5.2.9. Ranks: Uncommon<Common<Abundant.
.FISH_SHRIMP_RANK <- c(U = 1, C = 2, A = 3)
.FISH_SHRIMP_LABEL <- c("Uncommon", "Common", "Abundant")  # indexed by rank

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
    gcol <- col[g]; gnum <- num[g]; gmethod <- method[g]; gnet <- net[g]
    counts <- vapply(.FISH_SPECIES_COLS,
                     function(cc) sum(gnum[!is.na(gcol) & gcol == cc]), numeric(1))
    total <- sum(counts[.FISH_TOTAL_COLS])

    is_total <- !is.na(gcol) & gcol %in% .FISH_TOTAL_COLS
    # CPUE = catch (excl. koura & shrimp) per net/trap actually deployed. Effort
    # is the count of distinct Net/Trap # recorded for the method -- author-
    # confirmed (2026 regeneration review) over the earlier fixed 6 fyke / 12 GMT
    # protocol, since fewer nets may be set in a cycle. An empty net must be
    # recorded as a "no catch" row so it still counts toward effort here.
    cpue <- function(m) {
      sel <- gmethod == m & nzchar(gnet)
      n_traps <- length(unique(gnet[sel]))
      if (n_traps == 0L) return(NA_real_)
      sum(gnum[sel & is_total]) / n_traps
    }

    ranks <- .FISH_SHRIMP_RANK[shrimp_ab[g]]
    ranks <- ranks[!is.na(ranks)]
    shrimp_present <- length(ranks) > 0L
    shrimp <- if (!shrimp_present) "" else
      .FISH_SHRIMP_LABEL[floor(mean(ranks) + 0.5)]

    # Richness = number of taxa groups present + shrimp (if present).
    group_present <- vapply(.FISH_RICHNESS_GROUPS,
                            function(cc) any(counts[cc] > 0), logical(1))
    richness <- sum(group_present) + as.integer(shrimp_present)

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
