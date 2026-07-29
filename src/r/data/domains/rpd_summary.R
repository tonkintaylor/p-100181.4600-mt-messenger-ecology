# rpd_summary.R — per-site residual pool depth summary for report Appendix B1
# Table 4. R-only sheet (no Python counterpart). Reuses process_rpd_domain().
#
# One row per Site x Season x Year. Where a season has more than one survey, the
# surveys are pooled into a single combined sample: N is the total measurement
# count, Mean is the count-weighted pooled mean, and CI95 is the 95% t-CI
# half-width of the pooled sample (t(0.975, N-1) * pooled_sd / sqrt(N)).
#
# NB: this pools across surveys and recomputes the CI from the pooled sample, so
# it does not reuse the per-survey CI on the RPD sheet (both are t-based).
#
# SEASON: taken from the raw "Residual pool depths" sheet's own Season and Year
# columns -- author-confirmed 2026-07-29: use the sheet's value, do not infer it.
# .rpd_season_year() below is now only a fallback, for surveys the sheet leaves
# blank (baseline and event-based ones) and for workbooks that carry only the
# pre-summarised "RPD Summary" tab, which has no season labels at all.

# Fallback season assignment, by monitoring ROUND rather than strict
# meteorological month: the summer survey round runs Dec-Mar and the autumn round
# Apr-May. Confirmed by the report author (2026 regeneration review): spring
# surveys have run as late as December and summer surveys are typically
# Feb-March. Summer is labelled by its Jan-Mar year (Dec -> following year).
# This reproduces the report for the blank-Season surveys (Aug->Winter,
# Nov->Spring, Apr->Autumn).
.rpd_season_year <- function(dates) {
  m <- as.integer(format(dates, "%m"))
  y <- as.integer(format(dates, "%Y"))
  season <- rep(NA_character_, length(dates))
  season[m %in% c(12, 1, 2, 3)] <- "Summer"
  season[m %in% c(4, 5)]        <- "Autumn"
  season[m %in% c(6, 7, 8)]     <- "Winter"
  season[m %in% c(9, 10, 11)]   <- "Spring"
  y[m == 12] <- y[m == 12] + 1L
  list(season = season, year = y)
}

# Chronological rank within a labelled year (Summer is Jan/Feb, then Autumn...).
.RPD_SEASON_RANK <- c(Summer = 1L, Autumn = 2L, Winter = 3L, Spring = 4L)

process_rpd_summary_domain <- function(path) {
  rpd_res <- process_rpd_domain(path)
  if (is.null(rpd_res$data)) {
    return(DomainResult$new(data = NULL, errors = c(rpd_res$errors, list(
      ValidationError(domain = "RpdSummary", severity = "error",
        file = basename(path), sheet = "RPD Summary", location = "sheet",
        message = "RPD domain produced no data")))))
  }
  rpd <- rpd_res$data$RPD
  rpd$Date <- as.Date(rpd$Date)
  rpd <- rpd[!is.na(rpd$Date), , drop = FALSE]

  # Start from the date-derived labels, then overwrite with the raw sheet's own
  # Season/Year wherever it records them. The sheet wins; the derived values
  # survive only for surveys it leaves blank (baseline/event-based) and for
  # workbooks with no raw sheet at all.
  sy <- .rpd_season_year(rpd$Date)
  rpd$Season <- sy$season
  rpd$Year <- sy$year

  labels <- rpd_raw_season_labels(path)
  if (!is.null(labels)) {
    key <- function(site, date) {
      paste(site, as.integer(as.Date(date)), sep = "\r")
    }
    m <- match(key(rpd$Site, rpd$Date), key(labels$Site, labels$Date))
    matched <- which(!is.na(m))
    overwrite <- function(col, from) {
      take <- !is.na(from)
      col[matched[take]] <- from[take]
      col
    }
    rpd$Season <- overwrite(rpd$Season, labels$Season[m[matched]])
    rpd$Year <- overwrite(rpd$Year, labels$Year[m[matched]])
  }

  keys <- paste(rpd$Site, rpd$Season, rpd$Year, sep = "\r")
  rows <- lapply(split(seq_len(nrow(rpd)), keys), function(g) {
    cnt <- rpd$Count[g]; mn <- rpd$Mean[g]; sd_ <- rpd$StdDev[g]
    total_n <- sum(cnt)
    grand <- sum(cnt * mn) / total_n
    # Combined-sample variance from per-survey (n, mean, sd): within-survey
    # SS + between-survey SS, pooled over N-1 degrees of freedom.
    within <- ifelse(cnt > 1 & !is.na(sd_), (cnt - 1) * sd_^2, 0)
    between <- cnt * (mn - grand)^2
    ci95 <- NA_real_
    if (total_n > 1) {
      pooled_sd <- sqrt(sum(within + between) / (total_n - 1))
      ci95 <- stats::qt(0.975, total_n - 1) * pooled_sd / sqrt(total_n)
    }
    data.frame(Site = rpd$Site[g[1L]], Season = rpd$Season[g[1L]],
               Year = rpd$Year[g[1L]], N = as.integer(total_n),
               Mean = grand, CI95 = ci95,
               stringsAsFactors = FALSE, check.names = FALSE)
  })

  out <- do.call(rbind, rows)
  ord <- order(out$Site, out$Year, .RPD_SEASON_RANK[out$Season])
  out <- out[ord, RPD_SUMMARY_COLUMNS, drop = FALSE]
  rownames(out) <- NULL
  DomainResult$new(data = list(RpdSummary = out), errors = rpd_res$errors)
}
