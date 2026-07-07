# rpd_summary.R — per-site residual pool depth summary for report Appendix B1
# Table 4. R-only sheet (no Python counterpart). Reuses process_rpd_domain().
#
# One row per Site x Season x Year. Where a season has more than one survey, the
# surveys are pooled into a single combined sample: N is the total measurement
# count, Mean is the count-weighted pooled mean, and CI95 is the 95% t-CI
# half-width of the pooled sample (t(0.975, N-1) * pooled_sd / sqrt(N)).
#
# NB: this recomputes the CI with the t-distribution. The RPD sheet's stored
# CI_Lower/CI_Upper use a z (1.96) approximation and are NOT used here.

# Season by monitoring ROUND, not strict meteorological month: the summer survey
# round runs Dec-Mar and the autumn round Apr-May. Verified against the source's
# own Season labels (e.g. EM5's 12 Mar 2025 survey is recorded "Summer"). Summer
# is labelled by its Jan-Mar year (Dec -> following year).
# TODO(report-authors): confirm this round-based month mapping. The authoritative
# source is the "Residual pool depths" sheet's Season column, which is blank for
# baseline/event-based surveys -- this rule assigns those by date (Aug->Winter,
# Nov->Spring, Apr->Autumn), which reproduces the report.
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
  sy <- .rpd_season_year(rpd$Date)
  rpd$Season <- sy$season
  rpd$Year <- sy$year

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
