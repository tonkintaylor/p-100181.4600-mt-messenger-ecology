# nmds_plots.R — NMDS ordination plots for community analysis
#
# Exports:
#   plot_nmds_grouped(community_df, sites_subset, output_path, title, shape_title)
#   plot_nmds_per_site(community_df, output_dir)
#   plot_nmds_per_site_with_species(community_df, output_dir)
#   plot_indicator_species(community_df, grouping, output_dir)
#   export_species_drivers(community_df, grouping, output_dir)
#   export_dissimilarity_table(community_df, output_path)
#   export_indicator_species_combined(community_df, output_dir, sites)
#   export_indicator_species_by_catchment(community_df, catchments, output_dir)
#   export_species_drivers_combined(community_df, catchments, output_dir)
#   export_topspecies_with_abundance(community_df, output_dir)

library(vegan)
library(ggplot2)
library(dplyr)
library(tidyr)
library(ggrepel)
library(openxlsx)
library(zoo)


#' Run NMDS on a community data frame (filtered to specific sites).
#'
#' @param community_df Wide-format community data (Site, Date, Period, species...).
#' @param sites_subset Character vector of sites to include (NULL = all).
#' @param seed Random seed for reproducibility.
#' @return List with: nmds (metaMDS result), scores_df, species_scores_df.
run_site_nmds <- function(community_df, sites_subset = NULL, seed = 42) {

  if (!is.null(sites_subset)) {
    community_df <- community_df |> filter(Site %in% sites_subset)
  }

  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  species_data <- community_df[, species_cols]

  # Remove zero-sum columns (species absent from this subset)
  col_sums <- colSums(species_data, na.rm = TRUE)
  species_data <- species_data[, col_sums > 0, drop = FALSE]

  if (nrow(species_data) <= 2 || ncol(species_data) < 2) {
    warning("Too few samples/species for NMDS (n=", nrow(species_data),
            ", species=", ncol(species_data), ")")
    return(NULL)
  }

  set.seed(seed)
  nmds_result <- metaMDS(species_data, distance = "bray", k = 2, trymax = 100,
                         trace = 0)

  # Site scores
  scores_df <- as.data.frame(scores(nmds_result, display = "sites"))
  scores_df$Site <- community_df$Site
  scores_df$Date <- as.Date(community_df$Date)
  scores_df$Period <- community_df$Period

  # Temporal grouping
  scores_df <- scores_df |>
    mutate(
      MonthYearDate = as.yearmon(Date),
      MonthYear = format(MonthYearDate, "%b %Y"),
      MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
    )

  # Species scores (may be unavailable if WA scores couldn't be calculated)
  species_scores_df <- tryCatch({
    sp_scores <- as.data.frame(scores(nmds_result, display = "species"))
    if (nrow(sp_scores) > 0 && all(c("NMDS1", "NMDS2") %in% names(sp_scores))) {
      sp_scores$Species <- rownames(sp_scores)
      sp_scores$Influence <- sqrt(sp_scores$NMDS1^2 + sp_scores$NMDS2^2)
      sp_scores
    } else {
      data.frame(Species = character(), NMDS1 = numeric(), NMDS2 = numeric(),
                 Influence = numeric())
    }
  }, error = function(e) {
    data.frame(Species = character(), NMDS1 = numeric(), NMDS2 = numeric(),
               Influence = numeric())
  })

  list(
    nmds = nmds_result,
    scores = scores_df,
    species_scores = species_scores_df,
    stress = nmds_result$stress
  )
}


#' Plot grouped NMDS with temporal colours, site shapes, and convex hulls.
#'
#' @param nmds_data Output of run_site_nmds().
#' @param output_path File path to save the plot.
#' @param title Plot title.
#' @param shape_title Legend title for shapes.
#' @param shapes Named vector of shape codes (default: site_shapes()).
plot_nmds_grouped <- function(nmds_data, output_path, title = "NMDS Ordination",
                              shape_title = "Site", shapes = NULL) {
  if (is.null(nmds_data)) return(invisible(NULL))

  scores_df <- nmds_data$scores
  if (is.null(shapes)) shapes <- site_shapes()

  # Temporal colour palette
  n_dates <- length(levels(scores_df$MonthYear))
  colors <- temporal_palette(n_dates)

  # Convex hulls per site
  hull_data <- scores_df |>
    group_by(Site) |>
    slice(chull(NMDS1, NMDS2))

  p <- ggplot(scores_df, aes(x = NMDS1, y = NMDS2, colour = MonthYear, shape = Site)) +
    geom_polygon(data = hull_data,
                 aes(x = NMDS1, y = NMDS2, fill = Site, group = Site),
                 colour = "black", alpha = 0.2, inherit.aes = FALSE) +
    geom_point(size = 3, stroke = 1.1) +
    scale_color_manual(values = colors) +
    scale_shape_manual(values = shapes) +
    theme_ecology() +
    labs(
      title = title,
      x = "NMDS1", y = "NMDS2",
      colour = "Sampling Date",
      shape = shape_title,
      fill = shape_title
    )

  save_plot(p, output_path, width = 10, height = 8)
  invisible(p)
}


#' Plot per-site NMDS with linear regression trend arrow.
#'
#' Each site gets a separate NMDS ordination with:
#' - Temporal colour gradient (red → blue)
#' - Period-based shapes (circle=Baseline, triangle=Construction)
#' - Single regression arrow showing overall community direction
#'
#' @param community_df Wide-format community data.
#' @param output_dir Output directory.
#' @param catchment_lookup Named vector: site -> catchment name.
plot_nmds_per_site <- function(community_df, output_dir, catchment_lookup = NULL) {
  if (is.null(catchment_lookup)) catchment_lookup <- get_catchment_lookup()

  sites <- unique(community_df$Site)

  stress_results <- data.frame(Site = character(), Stress = numeric(),
                               stringsAsFactors = FALSE)

  for (site in sites) {
    nmds_data <- run_site_nmds(community_df, sites_subset = site)
    if (is.null(nmds_data)) next

    scores_df <- nmds_data$scores |> arrange(Date)
    stress_results <- rbind(stress_results,
                            data.frame(Site = site, Stress = nmds_data$stress))

    # Temporal colour palette
    n_dates <- length(levels(scores_df$MonthYear))
    colors <- temporal_palette(n_dates)

    # Linear regression for trend arrow
    tnum <- as.numeric(scores_df$Date)
    fit1 <- lm(NMDS1 ~ tnum, data = scores_df)
    fit2 <- lm(NMDS2 ~ tnum, data = scores_df)

    t_min <- min(tnum)
    t_max <- max(tnum)
    trend_df <- data.frame(
      start_x = predict(fit1, newdata = data.frame(tnum = t_min)),
      start_y = predict(fit2, newdata = data.frame(tnum = t_min)),
      end_x = predict(fit1, newdata = data.frame(tnum = t_max)),
      end_y = predict(fit2, newdata = data.frame(tnum = t_max))
    )

    # Catchment name for title
    catchment_name <- catchment_lookup[site]
    if (is.na(catchment_name)) catchment_name <- "Unknown"

    p <- ggplot(scores_df, aes(x = NMDS1, y = NMDS2, colour = MonthYear, shape = Period)) +
      geom_point(size = 3) +
      geom_segment(
        data = trend_df,
        aes(x = start_x, y = start_y, xend = end_x, yend = end_y),
        arrow = arrow(type = "closed", length = unit(0.15, "inches")),
        inherit.aes = FALSE, linewidth = 1, colour = "black"
      ) +
      scale_color_manual(values = colors) +
      scale_shape_manual(values = c("Baseline" = 16, "Routine Construction" = 17)) +
      theme_ecology() +
      labs(
        title = paste(catchment_name, "-", site),
        x = "NMDS1", y = "NMDS2",
        colour = "Sampling Date",
        shape = "Period"
      )

    # Filename: {Catchment}_{Site}.jpeg
    fname <- paste0(gsub(" ", "_", catchment_name), "_", gsub(" ", "_", site), ".jpeg")
    save_plot(p, file.path(output_dir, fname))
  }

  invisible(stress_results)
}


#' Plot per-site NMDS with species vectors overlaid (envfit arrows + labels).
#'
#' @param community_df Wide-format community data.
#' @param output_dir Output directory.
#' @param top_n Number of top species to display (default 10).
plot_nmds_per_site_with_species <- function(community_df, output_dir, top_n = 10) {
  sites <- unique(community_df$Site)
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)

  for (site in sites) {
    tryCatch({
      nmds_data <- run_site_nmds(community_df, sites_subset = site)
      if (!is.null(nmds_data) &&
          nrow(nmds_data$species_scores) > 0 &&
          all(c("NMDS1", "NMDS2") %in% names(nmds_data$species_scores))) {

        scores_df <- nmds_data$scores |> arrange(Date)
        species_scores <- nmds_data$species_scores

        # Top N most influential species
        top_species <- species_scores |>
          arrange(desc(Influence)) |>
          head(top_n)

        # Temporal colours
        n_dates <- length(levels(scores_df$MonthYear))
        colors <- temporal_palette(n_dates)

        p <- ggplot(scores_df, aes(x = NMDS1, y = NMDS2, colour = MonthYear)) +
          geom_point(size = 3) +
          geom_text_repel(
            data = top_species,
            aes(x = NMDS1, y = NMDS2, label = Species),
            size = 3, colour = "black",
            max.overlaps = Inf,
            box.padding = 0.4,
            point.padding = 0.2,
            segment.color = "grey50",
            inherit.aes = FALSE
          ) +
          scale_color_manual(values = colors) +
          theme_ecology() +
          labs(
            title = paste(site, "- Species Drivers"),
            x = "NMDS1", y = "NMDS2",
            colour = "Sampling Date"
          )

        fname <- paste0(gsub(" ", "_", site), "_NMDS_with_species.jpeg")
        save_plot(p, file.path(output_dir, fname))
      }
    }, error = function(e) {
      message("  Skipping species plot for ", site, ": ", e$message)
    })
  }
}


#' Run indicator species analysis and produce bar plots + xlsx.
#'
#' @param community_df Wide-format community data.
#' @param output_dir Output directory.
#' @param group_col Column to group by (default "Period").
#' @param scope_label Label for filenames (e.g., "all", "Mangapepeke_Sites").
plot_indicator_species <- function(community_df, output_dir,
                                   group_col = "Period", scope_label = "all") {
  library(indicspecies)

  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  species_data <- community_df[, species_cols]
  groups <- community_df[[group_col]]

  if (length(unique(groups)) < 2) {
    warning("Need at least 2 groups for indicator species analysis")
    return(invisible(NULL))
  }

  set.seed(42)
  indval_result <- multipatt(species_data, groups, func = "IndVal.g",
                             control = how(nperm = 999))

  # Extract significant species
  summary_df <- indval_result$sign |>
    tibble::rownames_to_column("Species") |>
    filter(p.value <= 0.05) |>
    arrange(p.value)

  if (nrow(summary_df) == 0) {
    message("  No significant indicator species for scope: ", scope_label)
    return(invisible(NULL))
  }

  # Bar plot of indicator values
  # Get the stat values from the indval object
  stat_df <- data.frame(
    Species = rownames(indval_result$sign),
    Stat = indval_result$sign$stat,
    PValue = indval_result$sign$p.value
  ) |>
    filter(PValue <= 0.05) |>
    arrange(desc(Stat)) |>
    head(20)

  p <- ggplot(stat_df, aes(x = reorder(Species, Stat), y = Stat)) +
    geom_col(fill = "#2ec4b6") +
    coord_flip() +
    labs(
      title = paste("Indicator Species -", scope_label),
      x = "Species",
      y = "IndVal Statistic"
    ) +
    theme_minimal(base_size = 12)

  save_plot(p, file.path(output_dir, paste0("indicator_species_", scope_label, ".jpeg")),
            width = 8, height = max(6, nrow(stat_df) * 0.3 + 2))

  # Export xlsx
  write.xlsx(summary_df,
             file.path(output_dir, paste0("indicator_species_", scope_label, ".xlsx")))
  message("  Exported indicator species xlsx: ", scope_label)

  invisible(summary_df)
}


#' Export envfit species drivers as xlsx.
#'
#' @param community_df Wide-format community data.
#' @param output_dir Output directory.
#' @param scope_label Label for filename.
#' @param p_threshold Significance threshold (default 0.05).
export_species_drivers <- function(community_df, output_dir,
                                   scope_label = "all", p_threshold = 0.05) {
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  species_data <- community_df[, species_cols]

  nmds_data <- run_site_nmds(community_df)
  if (is.null(nmds_data)) return(invisible(NULL))

  set.seed(42)
  ef <- envfit(nmds_data$nmds, species_data, permutations = 999)

  # Extract results
  vectors <- as.data.frame(scores(ef, display = "vectors"))
  vectors$Species <- rownames(vectors)
  vectors$R2 <- ef$vectors$r
  vectors$PValue <- ef$vectors$pvals

  sig_drivers <- vectors |>
    filter(PValue <= p_threshold) |>
    arrange(desc(R2))

  if (nrow(sig_drivers) > 0) {
    write.xlsx(sig_drivers,
               file.path(output_dir, paste0("significant_species_importance_", scope_label, ".xlsx")))
    message("  Exported species drivers: ", scope_label, " (", nrow(sig_drivers), " significant)")
  }

  invisible(sig_drivers)
}


#' Export Bray-Curtis dissimilarity matrix as xlsx.
#'
#' @param community_df Wide-format community data.
#' @param output_path Output xlsx path.
export_dissimilarity_table <- function(community_df, output_path) {
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  species_data <- community_df[, species_cols]

  dm <- as.matrix(vegdist(species_data, method = "bray"))

  # Use Site_Date as row/col names
  sample_ids <- paste(community_df$Site, format(community_df$Date, "%Y-%m-%d"), sep = "_")
  rownames(dm) <- sample_ids
  colnames(dm) <- sample_ids

  write.xlsx(as.data.frame(dm), output_path, rowNames = TRUE)
  message("  Exported dissimilarity table: ", output_path)
}


#' Combine per-site indicator species results into a single multi-sheet workbook.
#'
#' @param community_df Wide-format community data.
#' @param output_dir Output directory.
#' @param sites Character vector of sites to include.
export_indicator_species_combined <- function(community_df, output_dir, sites = NULL) {
  library(indicspecies)

  if (is.null(sites)) sites <- unique(community_df$Site)

  wb <- createWorkbook()
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)

  for (site in sites) {
    site_df <- community_df |> filter(Site == site)
    if (nrow(site_df) <= 3 || length(unique(site_df$Period)) < 2) next

    species_data <- site_df[, species_cols]
    col_sums <- colSums(species_data, na.rm = TRUE)
    species_data <- species_data[, col_sums > 0, drop = FALSE]
    if (ncol(species_data) < 2) next

    groups <- site_df$Period
    set.seed(42)
    tryCatch({
      indval <- multipatt(species_data, groups, func = "IndVal.g",
                          control = how(nperm = 999))
      summary_df <- indval$sign |>
        tibble::rownames_to_column("Species") |>
        pivot_longer(cols = starts_with("s."), names_to = "Phase",
                     values_to = "presence") |>
        mutate(Phase = gsub("^s\\.", "", Phase)) |>
        select(Species, Phase, stat, p.value, presence)

      sheet_name <- substr(gsub("[^A-Za-z0-9_]", "", site), 1, 31)
      addWorksheet(wb, sheet_name)
      writeData(wb, sheet_name, summary_df)
    }, error = function(e) {
      message("  Skipping ISA for site ", site, ": ", e$message)
    })
  }

  out_path <- file.path(output_dir, "indicator_species_all_sites.xlsx")
  if (length(wb$sheet_names) > 0) {
    saveWorkbook(wb, out_path, overwrite = TRUE)
    message("  Exported combined indicator species: ", out_path)
  }
}


#' Indicator species analysis grouped by catchment (baseline vs construction).
#'
#' @param community_df Wide-format community data.
#' @param catchments Named list of site vectors per catchment.
#' @param output_dir Output directory.
export_indicator_species_by_catchment <- function(community_df, catchments, output_dir) {
  library(indicspecies)

  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  all_results <- data.frame()

  for (catchment_name in names(catchments)) {
    subset_sites <- catchments[[catchment_name]]
    subset_df <- community_df |> filter(Site %in% subset_sites)
    if (nrow(subset_df) <= 3 || length(unique(subset_df$Period)) < 2) next

    species_data <- subset_df[, species_cols]
    col_sums <- colSums(species_data, na.rm = TRUE)
    species_data <- species_data[, col_sums > 0, drop = FALSE]
    if (ncol(species_data) < 2) next

    groups <- subset_df$Period
    set.seed(42)
    tryCatch({
      indval <- multipatt(species_data, groups, func = "IndVal.g",
                          control = how(nperm = 999))
      group_levels <- sort(unique(groups))
      sig_df <- indval$sign |>
        tibble::rownames_to_column("Species") |>
        filter(p.value <= 0.05) |>
        mutate(
          Phase = sapply(index, function(i) {
            paste(group_levels[as.logical(intToBits(i)[seq_along(group_levels)])],
                  collapse = "+")
          }),
          Catchment = catchment_name
        ) |>
        select(Species, Phase, stat, p.value, Catchment)
      all_results <- rbind(all_results, sig_df)
    }, error = function(e) {
      message("  Skipping catchment ISA for ", catchment_name, ": ", e$message)
    })
  }

  if (nrow(all_results) > 0) {
    out_path <- file.path(output_dir,
                          "indicator_species_baseline_vs_construction_by_catchment.xlsx")
    write.xlsx(all_results, out_path)
    message("  Exported ISA by catchment: ", out_path)
  }
}


#' Export combined envfit drivers with catchment labels.
#'
#' @param community_df Wide-format community data.
#' @param catchments Named list of site vectors per catchment.
#' @param output_dir Output directory.
#' @param p_threshold Significance threshold.
export_species_drivers_combined <- function(community_df, catchments, output_dir,
                                            p_threshold = 0.05) {
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  all_drivers <- data.frame()

  for (catchment_name in names(catchments)) {
    subset_sites <- catchments[[catchment_name]]
    subset_df <- community_df |> filter(Site %in% subset_sites)
    if (nrow(subset_df) <= 3) next

    species_data <- subset_df[, species_cols]
    col_sums <- colSums(species_data, na.rm = TRUE)
    species_data <- species_data[, col_sums > 0, drop = FALSE]
    if (ncol(species_data) < 2) next

    nmds_data <- run_site_nmds(subset_df)
    if (is.null(nmds_data)) next

    set.seed(42)
    ef <- envfit(nmds_data$nmds, species_data, permutations = 999)
    vectors <- as.data.frame(scores(ef, display = "vectors"))
    vectors$Species <- rownames(vectors)
    vectors$r <- ef$vectors$r
    vectors$p <- ef$vectors$pvals
    vectors$Catchment <- catchment_name

    sig <- vectors |> filter(p <= p_threshold)
    all_drivers <- rbind(all_drivers, sig)
  }

  if (nrow(all_drivers) > 0) {
    out <- all_drivers |>
      select(Species, NMDS1, NMDS2, r, p, Catchment) |>
      arrange(p)
    write.xlsx(out, file.path(output_dir, "species_drivers_sig.xlsx"))
    message("  Exported combined species drivers: ", nrow(out), " significant")
  }
}


#' Export envfit drivers joined with abundance change per site.
#'
#' @param community_df Wide-format community data.
#' @param output_dir Output directory.
#' @param p_threshold Significance threshold.
export_topspecies_with_abundance <- function(community_df, output_dir,
                                             p_threshold = 0.05) {
  meta_cols <- c("Site", "Date", "Period")
  species_cols <- setdiff(names(community_df), meta_cols)
  all_results <- data.frame()

  for (site in unique(community_df$Site)) {
    site_df <- community_df |> filter(Site == site)
    if (nrow(site_df) <= 3) next

    species_data <- site_df[, species_cols]
    col_sums <- colSums(species_data, na.rm = TRUE)
    species_data <- species_data[, col_sums > 0, drop = FALSE]
    if (ncol(species_data) < 2) next

    nmds_data <- run_site_nmds(site_df)
    if (is.null(nmds_data)) next

    set.seed(42)
    ef <- envfit(nmds_data$nmds, species_data, permutations = 999)
    vectors <- as.data.frame(scores(ef, display = "vectors"))
    vectors$Species <- rownames(vectors)
    vectors$r <- ef$vectors$r
    vectors$p <- ef$vectors$pvals

    sig <- vectors |> filter(p <= p_threshold)
    if (nrow(sig) == 0) next

    # Compute abundance change across periods
    baseline_means <- site_df |>
      filter(Period == "Baseline") |>
      select(all_of(species_cols)) |>
      colMeans(na.rm = TRUE)
    construction_means <- site_df |>
      filter(Period == "Routine Construction") |>
      select(all_of(species_cols)) |>
      colMeans(na.rm = TRUE)
    incident_df <- site_df |> filter(Period == "Incident")
    if (nrow(incident_df) > 0) {
      incident_means <- incident_df |>
        select(all_of(species_cols)) |>
        colMeans(na.rm = TRUE)
    } else {
      incident_means <- rep(NA_real_, length(species_cols))
      names(incident_means) <- species_cols
    }

    abundance_change <- data.frame(
      Species = names(baseline_means),
      Baseline = baseline_means,
      `Routine Construction` = construction_means,
      Incident = incident_means,
      check.names = FALSE,
      stringsAsFactors = FALSE
    ) |>
      mutate(
        `Actual Change` = `Routine Construction` - Baseline,
        `Percentage Change` = ifelse(
          Baseline > 0,
          round((`Routine Construction` - Baseline) / Baseline * 100, 1),
          NA_real_
        )
      )

    site_result <- sig |>
      select(Species, NMDS1, NMDS2, r, p) |>
      mutate(Site = site) |>
      left_join(abundance_change, by = "Species")
    all_results <- rbind(all_results, site_result)
  }

  if (nrow(all_results) > 0) {
    all_results <- all_results |> arrange(Site, p)
    write.xlsx(all_results, file.path(output_dir, "topspecies_individualsites.xlsx"))
    message("  Exported top species with abundance: ", nrow(all_results), " rows")

    # Also produce NMDS_stats_basleline_construction.xlsx (subset of columns)
    nmds_stats <- all_results |>
      select(Species, NMDS1, NMDS2, r, p, Site, Baseline, `Routine Construction`,
             Incident, `Actual Change`)
    write.xlsx(nmds_stats, file.path(output_dir, "NMDS_stats_basleline_construction.xlsx"))
    message("  Exported NMDS stats baseline/construction: ", nrow(nmds_stats), " rows")
  }
}
