# report_tables.R — transform the tidy summary sheets (from Data.xlsx) into the
# wide, report-shaped tables and render them to a single self-contained HTML
# file that opens in / pastes into Word. No external package dependencies.
#
# Each builder returns a list of "sections": list(title = <chr>, table = <df>),
# ordered newest-first. render_report_tables_html() concatenates every section
# from every builder into one HTML document.

.RT_DASH <- "–"                                   # en dash, the report's "not recorded"
.RT_SEASON_RANK <- c(Summer = 1L, Autumn = 2L, Winter = 3L, Spring = 4L)

# Chronological sort key for a Season + Year (higher = more recent).
.rt_season_key <- function(season, year) {
  as.integer(year) * 10L + unname(.RT_SEASON_RANK[season])
}

# Year vector for df: the Year column if present, else derived from Date
# (SedimentSummary is keyed by Date only, with no Year column).
.rt_year <- function(df) {
  if ("Year" %in% names(df)) as.integer(df$Year)
  else as.integer(format(as.Date(df$Date), "%Y"))
}

# Distinct (Season, Year) groups present in df, most-recent first. Only the four
# standard survey seasons are kept -- this drops "incident response" (Additional
# flood-response) rows, which are not part of the seasonal appendix tables.
.rt_seasons <- function(df) {
  g <- unique(data.frame(Season = as.character(df$Season), Year = .rt_year(df),
                         stringsAsFactors = FALSE))
  g <- g[g$Season %in% names(.RT_SEASON_RANK), , drop = FALSE]
  g[order(-.rt_season_key(g$Season, g$Year)), , drop = FALSE]
}

# Format a numeric value (optionally x100 for %, optionally +/- CI) or the dash.
.rt_num <- function(v, ci = NA_real_, dp = 1, scale = 1) {
  if (length(v) != 1 || is.na(v)) return(.RT_DASH)
  s <- formatC(round(v * scale, dp), format = "f", digits = dp)
  if (length(ci) == 1 && !is.na(ci)) {
    s <- paste0(s, " (±", formatC(round(ci * scale, dp), format = "f",
                                       digits = dp), ")")
  }
  s
}

# Integer catch count; blank for zero/absent (as the fish/macro tables print).
.rt_count <- function(v) {
  if (length(v) != 1 || is.na(v) || v == 0) return("")
  formatC(round(v), format = "d")
}

.rt_chr <- function(x) if (length(x) != 1 || is.na(x) || !nzchar(x)) .RT_DASH else x

# Format a date value as dd/mm/yyyy (the report's convention), or the dash.
.rt_date <- function(x) {
  if (length(x) < 1) return(.RT_DASH)
  d <- as.Date(x[1])
  if (is.na(d)) return(.RT_DASH)
  format(d, "%d/%m/%Y")
}

# Build a "metrics as rows, sites as columns" table from a per-season slice that
# has one row per site. rows_spec: list(list(label=, value=function(site_row))).
.rt_site_columns <- function(sub, rows_spec) {
  sites <- sort(unique(as.character(sub$Site)))
  out <- data.frame(Variable = vapply(rows_spec, function(r) r$label, character(1)),
                    stringsAsFactors = FALSE, check.names = FALSE)
  for (st in sites) {
    r <- sub[as.character(sub$Site) == st, , drop = FALSE][1, , drop = FALSE]
    out[[st]] <- vapply(rows_spec, function(rw) rw$value(r), character(1))
  }
  out
}

# =====================================================================
# Tables 5.6 & 5.7 — macroinvertebrate community metrics (one table per survey)
# The community-indices table appears once per survey in the current reporting
# period, numbered sequentially: spring 2025 = 5.6, summer 2026 = 5.7. Older
# surveys carried in the MacroSummary sheet (back to 2018) have no report table
# number and are skipped. Extend .RT_MACRO_TABLE_NO as future periods are added.
# =====================================================================
.RT_MACRO_TABLE_NO <- c("Spring 2025" = "5.6", "Summer 2026" = "5.7")

rt_macro_summary <- function(df) {
  rows <- list(
    list(label = "Catchment",                 value = function(r) .rt_chr(r$Catchment)),
    list(label = "Substrate",                  value = function(r) .rt_chr(r$Substrate)),
    list(label = "Method",                     value = function(r) .rt_chr(r$Method)),
    list(label = "Date",                       value = function(r) .rt_date(r$Date)),
    list(label = "Number of individuals",      value = function(r) .rt_num(r$NumIndividuals, r$NumIndividuals_CI)),
    list(label = "Number of taxa",             value = function(r) .rt_num(r$NumTaxa, r$NumTaxa_CI)),
    list(label = "MCI score",                  value = function(r) .rt_num(r$MCI, r$MCI_CI, dp = 1)),
    list(label = "MCI quality class",          value = function(r) .rt_chr(r$MCI_Class)),
    list(label = "QMCI score",                 value = function(r) .rt_num(r$QMCI, r$QMCI_CI, dp = 2)),
    list(label = "QMCI quality class",         value = function(r) .rt_chr(r$QMCI_Class)),
    list(label = "% EPT richness",             value = function(r) .rt_num(r$PctEPTRichness, r$PctEPTRichness_CI, scale = 100)),
    list(label = "% EPT abundance",            value = function(r) .rt_num(r$PctEPTAbundance, r$PctEPTAbundance_CI, scale = 100)),
    list(label = "Dominant taxa",              value = function(r) .rt_chr(r$DominantTaxa)))
  # Index the season slices by "Season Year" so we can emit them in ascending
  # report-table-number order, keeping only surveys that have a number.
  slices <- split_seasons(df)
  keys <- vapply(slices, function(s) sprintf("%s %d", s$Season, s$Year), character(1))
  out <- list()
  for (key in names(.RT_MACRO_TABLE_NO)) {
    idx <- which(keys == key)
    if (length(idx) == 0L) next
    s <- slices[[idx[1L]]]
    out[[length(out) + 1L]] <- list(
      title = sprintf("Table %s — Macroinvertebrate community metrics, %s %d",
                      .RT_MACRO_TABLE_NO[[key]], s$Season, s$Year),
      table = .rt_site_columns(s$data, rows))
  }
  out
}

# =====================================================================
# Table 5.8 — freshwater fish surveys (one table per season)
# =====================================================================
.RT_FISH_SPECIES <- c(
  LongfinEel = "Longfin eel", ShortfinEel = "Shortfin eel",
  CommonBully = "Common bully", RedfinBully = "Redfin bully",
  BandedKokopu = "Banded kōkopu", GiantKokopu = "Giant kōkopu",
  Inanga = "Īnanga", UnidBully = "Unid. bully sp.",
  UnidKokopu = "Unid. kōkopu sp.", UnidGalaxiid = "Unid. galaxiid sp.",
  UnidEel = "Unid. eel sp.", Koura = "Kōura")

rt_fish <- function(df) {
  species_rows <- lapply(names(.RT_FISH_SPECIES), function(col) {
    list(label = unname(.RT_FISH_SPECIES[col]),
         value = function(r) .rt_count(r[[col]]))
  })
  rows <- c(
    list(list(label = "Catchment", value = function(r) .rt_chr(r$Catchment))),
    species_rows,
    list(list(label = "Shrimp",              value = function(r) .rt_chr(r$Shrimp)),
         list(label = "Total fish caught*",  value = function(r) .rt_num(r$TotalFish, dp = 0)),
         list(label = "Taxa richness",       value = function(r) .rt_num(r$TaxaRichness, dp = 0)),
         list(label = "CPUE (fykes)",        value = function(r) .rt_num(r$CPUE_fykes, dp = 2)),
         list(label = "CPUE (GMTs)",         value = function(r) .rt_num(r$CPUE_GMTs, dp = 2))))
  lapply(split_seasons(df), function(s) list(
    title = sprintf("Table 5.8 — Freshwater fish surveys, %s %d",
                    s$Season, s$Year),
    table = .rt_site_columns(s$data, rows)))
}

# =====================================================================
# Appendix B3 — spot water quality (one table per season)
# =====================================================================
rt_field_wq <- function(df) {
  rows <- list(
    list(label = "Catchment",                     value = function(r) .rt_chr(r$Catchment)),
    list(label = "Date",                          value = function(r) .rt_date(r$Date)),
    list(label = "Time taken",                    value = function(r) .rt_chr(r$TimeTaken)),
    list(label = "Water temperature (°C)",   value = function(r) .rt_num(r$WaterTempC, dp = 1)),
    list(label = "pH",                            value = function(r) .rt_num(r$pH, dp = 2)),
    list(label = "Specific conductivity (µS/cm)", value = function(r) .rt_num(r$SpecCond, dp = 1)),
    list(label = "DO (mg/L)",                      value = function(r) .rt_num(r$DO_mgL, dp = 2)),
    list(label = "DO (% sat.)",                    value = function(r) .rt_num(r$DO_pctSat, dp = 1)))
  lapply(split_seasons(df), function(s) {
    tbl <- .rt_site_columns(s$data, rows)   # cols: Variable, EM1, EM2, ...
    sites <- names(tbl)[-1]
    # Two-row header: the Catchment banner (row 1 = column names) sits above the
    # site codes (row 2 = a "Site" body row). The Catchment values built by the
    # rows spec become the column names; the measurement rows stay beneath.
    catch <- as.character(unlist(tbl[tbl$Variable == "Catchment", -1],
                                 use.names = FALSE))
    body <- tbl[tbl$Variable != "Catchment", , drop = FALSE]
    site_row <- as.data.frame(as.list(c("Site", sites)),
                              stringsAsFactors = FALSE, check.names = FALSE)
    names(site_row) <- names(body)
    body <- rbind(site_row, body)
    names(body) <- c("Catchment", catch)
    rownames(body) <- NULL
    list(title = sprintf("Appendix B3 — Spot water quality, %s %d",
                         s$Season, s$Year),
         table = body)
  })
}

# =====================================================================
# Appendix B1 Table 3 — deposited sediment + substrate (one per season)
# Long input (Protocol/Variable/Value): rows = measurements, cols = sites.
# =====================================================================
rt_sediment_summary <- function(df) {
  lapply(split_seasons(df), function(s) {
    sub <- s$data
    sites <- sort(unique(as.character(sub$Site)))
    # Preserve the measurement order as it appears in the sheet.
    meas <- unique(sub[, c("Protocol", "Variable")])
    out <- data.frame(Protocol = meas$Protocol, Variable = meas$Variable,
                      stringsAsFactors = FALSE, check.names = FALSE)
    for (st in sites) {
      vals <- vapply(seq_len(nrow(meas)), function(i) {
        v <- sub$Value[as.character(sub$Site) == st &
                         sub$Protocol == meas$Protocol[i] &
                         sub$Variable == meas$Variable[i]]
        .rt_num(if (length(v)) v[1] else NA_real_, dp = 0)
      }, character(1))
      out[[st]] <- vals
    }
    # Date row directly below the site-name header: one sample date per site.
    date_row <- data.frame(Protocol = "", Variable = "Date",
                           stringsAsFactors = FALSE, check.names = FALSE)
    for (st in sites) {
      d <- sub$Date[as.character(sub$Site) == st]
      date_row[[st]] <- .rt_date(d)
    }
    out <- rbind(date_row, out)
    list(title = sprintf("Appendix B1 Table 3 — Sediment cover & substrate, %s %d",
                         s$Season, s$Year),
         table = out)
  })
}

# =====================================================================
# Appendix B1 Table 4 — residual pool depth (single site x season matrix)
# =====================================================================
rt_rpd_summary <- function(df) {
  seasons <- .rt_seasons(df)
  seasons <- seasons[order(.rt_season_key(seasons$Season, seasons$Year)), , drop = FALSE]  # chronological
  labels <- sprintf("%s %d", seasons$Season, seasons$Year)
  sites <- sort(unique(as.character(df$Site)))
  out <- data.frame(Site = sites, stringsAsFactors = FALSE, check.names = FALSE)
  for (i in seq_len(nrow(seasons))) {
    out[[labels[i]]] <- vapply(sites, function(st) {
      r <- df[as.character(df$Site) == st & df$Season == seasons$Season[i] &
                df$Year == seasons$Year[i], , drop = FALSE]
      if (nrow(r) == 0) return(.RT_DASH)
      .rt_num(r$Mean[1], r$CI95[1], dp = 1)
    }, character(1))
  }
  list(list(title = "Appendix B1 Table 4 — Mean residual pool depth (±95% CI)",
            table = out))
}

# =====================================================================
# Appendix B2 — raw macroinvertebrate counts (one table per season)
# Long input: rows = taxa (+ MCI/MCI-sb), cols = Site x Replicate samples.
# =====================================================================
rt_macro_sample <- function(df) {
  lapply(split_seasons(df), function(s) {
    sub <- s$data
    # Sample columns: Site x Replicate, ordered; header "EM3.1" (or "EM1").
    samp <- unique(sub[, c("Site", "Replicate")])
    samp <- samp[order(as.character(samp$Site),
                       ifelse(is.na(samp$Replicate), 0L, samp$Replicate)), , drop = FALSE]
    samp_label <- ifelse(is.na(samp$Replicate), as.character(samp$Site),
                         paste0(samp$Site, ".", samp$Replicate))
    # Taxa rows, grouped by TaxaGroup then Species.
    taxa <- unique(sub[, c("TaxaGroup", "Species", "MCI", "MCI_sb")])
    taxa <- taxa[order(taxa$TaxaGroup, taxa$Species), , drop = FALSE]
    out <- data.frame(TaxaGroup = taxa$TaxaGroup, Species = taxa$Species,
                      MCI = vapply(taxa$MCI, .rt_num, character(1), dp = 1),
                      `MCI-sb` = vapply(taxa$MCI_sb, .rt_num, character(1), dp = 1),
                      stringsAsFactors = FALSE, check.names = FALSE)
    for (j in seq_len(nrow(samp))) {
      out[[samp_label[j]]] <- vapply(seq_len(nrow(taxa)), function(i) {
        sel <- as.character(sub$Site) == as.character(samp$Site[j]) &
          ((is.na(samp$Replicate[j]) & is.na(sub$Replicate)) |
             (!is.na(sub$Replicate) & sub$Replicate == samp$Replicate[j])) &
          sub$Species == taxa$Species[i] & sub$TaxaGroup == taxa$TaxaGroup[i]
        .rt_count(if (any(sel)) sub$Count[sel][1] else 0)
      }, character(1))
    }
    # Date row directly below the sample-name header: one date per sample column
    # (all replicates of a site share the site's sampling date).
    date_row <- data.frame(TaxaGroup = "Date", Species = "", MCI = "",
                           `MCI-sb` = "", stringsAsFactors = FALSE,
                           check.names = FALSE)
    for (j in seq_len(nrow(samp))) {
      d <- sub$Date[as.character(sub$Site) == as.character(samp$Site[j])]
      date_row[[samp_label[j]]] <- .rt_date(d)
    }
    out <- rbind(date_row, out)
    list(title = sprintf("Appendix B2 — Macroinvertebrate sampling data, %s %d",
                         s$Season, s$Year),
         table = out)
  })
}

# Split a tidy df into per-season slices, most-recent first.
split_seasons <- function(df) {
  yr <- .rt_year(df)
  seasons <- .rt_seasons(df)
  lapply(seq_len(nrow(seasons)), function(i) list(
    Season = seasons$Season[i], Year = seasons$Year[i],
    data = df[as.character(df$Season) == seasons$Season[i] &
                yr == seasons$Year[i], , drop = FALSE]))
}

# ---- xlsx rendering -------------------------------------------------

# Read every summary sheet from Data.xlsx and build the report-table sections,
# grouped BY TABLE TYPE (one group per builder) in report order. Each group is
# list(file = <file stem>, sections = list(list(title=, table=), ...)); each
# builder applies its own season ordering within the group.
.rt_collect_groups <- function(data_xlsx) {
  read_sheet <- function(name) {
    df <- suppressWarnings(readxl::read_excel(data_xlsx, sheet = name))
    names(df) <- trimws(names(df))
    as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
  }
  spec <- list(
    list(fn = rt_macro_summary,    sheet = "MacroSummary",    file = "Macroinvertebrate_community_metrics"),
    list(fn = rt_fish,             sheet = "FishSummary",     file = "Freshwater_fish_surveys"),
    list(fn = rt_sediment_summary, sheet = "SedimentSummary", file = "Sediment_cover_and_substrate"),
    list(fn = rt_rpd_summary,      sheet = "RpdSummary",      file = "Residual_pool_depth"),
    list(fn = rt_macro_sample,     sheet = "MacroSampleData", file = "Macroinvertebrate_sampling_data"),
    list(fn = rt_field_wq,         sheet = "FieldWQ",         file = "Spot_water_quality"))
  groups <- list()
  for (s in spec) {
    df <- tryCatch(read_sheet(s$sheet), error = function(e) NULL)
    if (is.null(df) || nrow(df) == 0) next
    secs <- s$fn(df)
    if (length(secs) == 0L) next
    groups[[length(groups) + 1L]] <- list(file = s$file, sections = secs)
  }
  groups
}

# A valid, unique Excel worksheet name for a section: prefer the trailing
# "Season Year" (e.g. "Spring 2025"); else the title text after the em dash.
# Excel caps names at 31 chars and forbids : \ / ? * [ ]; de-duplicate too.
.rt_sheet_name <- function(title, used = character(0)) {
  m <- regmatches(title, regexpr("(Spring|Summer|Autumn|Winter) [0-9]{4}$", title))
  name <- if (length(m) == 1L && nzchar(m)) m else sub("^.*—\\s*", "", title)
  name <- trimws(gsub("\\s+", " ", gsub("[:\\\\/?*\\[\\]]", " ", name)))
  if (nchar(name) > 31L) name <- substr(name, 1L, 31L)
  base <- name
  k <- 2L
  while (name %in% used) {
    suffix <- sprintf(" (%d)", k)
    name <- paste0(substr(base, 1L, 31L - nchar(suffix)), suffix)
    k <- k + 1L
  }
  name
}

#' Render the report tables to out_dir as ONE .xlsx per table TYPE, with one
#' worksheet per table within that type (author preference: minimise file
#' count). Files are index-prefixed so they list in report order.
#' @param data_xlsx path to MtMessengerEcologyData.xlsx (with the *Summary sheets)
#' @param out_dir   destination directory (created if absent)
#' @return character vector of the .xlsx paths written
render_report_tables_xlsx <- function(data_xlsx, out_dir) {
  stopifnot(file.exists(data_xlsx))
  groups <- .rt_collect_groups(data_xlsx)
  if (!dir.exists(out_dir) &&
      !isTRUE(dir.create(out_dir, showWarnings = FALSE, recursive = TRUE))) {
    stop(sprintf("Could not create output directory '%s' - check the path exists and is writable.",
                 out_dir))
  }
  paths <- character(0)
  for (i in seq_along(groups)) {
    g <- groups[[i]]
    path <- file.path(out_dir, sprintf("%02d_%s.xlsx", i, g$file))
    wb <- openxlsx::createWorkbook()
    used <- character(0)
    for (sec in g$sections) {
      sheet <- .rt_sheet_name(sec$title, used)
      used <- c(used, sheet)
      openxlsx::addWorksheet(wb, sheet)
      openxlsx::writeData(wb, sheet, sec$table)
    }
    openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
    paths <- c(paths, path)
  }
  invisible(paths)
}
