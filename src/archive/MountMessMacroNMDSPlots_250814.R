# Update working directory to relevant quarterly folder.
setwd("//ttgroup.local/corporate/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2024-2025 Report/Stats")
library(ggplot2)
library(ggrepel)
library(scales)
library(RColorBrewer)
library(lubridate)
library(dplyr)
library(tidyr)
library(gridExtra)
library(grid)
library(ggpubr)
library(readxl)
library(cowplot)
library(magrittr)
library(ggridges)
library(vegan)
library(reshape2)
library(zoo)
library(indicspecies)
library(forcats)
library(tibble)
library(stringr)
library(openxlsx)
library(forcats)
library(grDevices)

# Update file and sheet names to relevant date. Copy excel file from previous quarter and add new data.
macrospecies <- read_xlsx("Data.xlsx", sheet = "MacroSpecies")

#Data prep
macrospeciesmean_all <- macrospecies %>%
  group_by(Site, Phase, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")

macro_matrix_all <- macrospeciesmean_all %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_all <- macro_matrix_all %>% select(-SampleID, -Site, -Date, -Phase)





#Dissimilarity
dissimilarity_matrix <- vegdist(species_data_all, method = "bray")

nmds_scores_all <- as.data.frame(scores(dissimilarity_matrix, display = "sites"))
nmds_scores_species_all <- as.data.frame(scores(dissimilarity_matrix, display = "species"))
nmds_scores_all$Site <- macro_matrix_all$Site
nmds_scores_all$Date <- macro_matrix_all$Date

grouping_factor <- nmds_scores_all$Site
grouping_factor_1_2_3 <- grouping_factor[grouping_factor %in% c("EM1", "EM2", "EM3")]
grouping_factor_4_7_8 <- grouping_factor[grouping_factor %in% c("EM4", "EM7", "EM8")]


anosim_result <- anosim(dissimilarity_matrix, grouping_factor, permutations = 999)
summary(anosim_result)
plot(anosim_result)

#Export dissimilarity table
write.xlsx(nmds_scores_all, 'Dissimilarity_Table.xlsx')




# Indicator species assessment - note this was not useful as it only showed indicator species for baseline.
wb <- createWorkbook()

# Sites to exclude
exclude_sites <- c("MMA 6", "MMA 6b")

# Filter out excluded sites before looping
sites <- setdiff(unique(macro_matrix_all$Site), exclude_sites)

for (site in sites) {
  
  message("Processing site: ", site)
  
  site_data <- macro_matrix_all %>%
    filter(Site == site) %>%
    select(-SampleID, -Site, -Date)
  
  # Grouping factor
  grouping_factor <- site_data$Phase
  site_data <- select(site_data, -Phase)
  
  # Skip if less than 2 groups present
  if (length(unique(grouping_factor)) < 2) {
    message(paste("Skipping", site, "- only one phase present"))
    next
  }
  
  # Run indicator species analysis
  isa_result <- multipatt(site_data, grouping_factor, func = "IndVal.g",
                          control = how(nperm = 999))
  
  # Prepare summary table with all species
  isa_summary <- as.data.frame(isa_result$sign) %>%
    tibble::rownames_to_column("Species") %>%
    pivot_longer(cols = starts_with("s."),
                 names_to = "Phase",
                 values_to = "presence") %>%
    mutate(
      Phase = gsub("^s\\.", "", Phase)
    ) %>%
    select(Species, Phase, stat, p.value, presence)
  
  # Save to Excel
  addWorksheet(wb, site)
  writeData(wb, site, isa_summary)
  
  # Plot
  plot <- ggplot(isa_summary, aes(x = Species, y = stat, fill = Phase)) +
    geom_col(position = "dodge", width = 0.7) +
    labs(
      title = paste("Indicator Species -", site),
      x = "Species",
      y = "Indicator Value",
      fill = "Phase"
    ) +
    coord_flip() +
    theme_minimal(base_size = 13) +
    theme(
      axis.text.y = element_text(face = "italic"),
      plot.title = element_text(face = "bold")
    )
  
  ggsave(paste0("indicator_species_", site, ".jpeg"), plot, width = 8, height = 6)
}

# Save Excel workbook
saveWorkbook(wb, "indicator_species_all_sites.xlsx", overwrite = TRUE)



# Preprocess data
macrospecies <- macrospecies %>%
  mutate(
    Date = as.Date(Date),
    Site = case_when(
      Site == "EM1" ~ "EM1 Control",
      Site == "EM4" ~ "EM4 Control",
      Site == "EM5" ~ "EM5 Control",
      TRUE ~ Site
    ),
    Catchment = case_when(
      Site %in% c("EM4 Control", "EM5 Control", "EM7", "EM8") ~ "Mimi",
      Site %in% c("EM1 Control", "EM2", "EM3") ~ "Mangapēpeke",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!grepl("^MMA", Site))

catchment_lookup <- setNames(macrospecies$Catchment, macrospecies$Site)

# NMDS + envfit plotting function
plot_site_nmds <- function(site_data, site_name) {
  
  # Prepare wide community matrix
  macro_site <- site_data %>%
    group_by(Site, Date, Species) %>%
    summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop") %>%
    unite("SampleID", Site, Date, remove = FALSE) %>%
    pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)
  
  species_data <- macro_site %>% select(-SampleID, -Site, -Date)
  if (nrow(species_data) <= 2) return(NULL)
  
  # NMDS
  set.seed(123)
  nmds <- metaMDS(species_data, distance = "bray", k = 2, trymax = 100)
  
  # Scores
  scores_df <- as.data.frame(scores(nmds, display = "sites"))
  scores_df$Site <- macro_site$Site
  scores_df$Date <- as.Date(macro_site$Date)
  scores_df <- scores_df %>%
    arrange(Date) %>%
    mutate(
      Period = if_else(Date < as.Date("2022-07-01"), "Baseline", "Construction"),
      MonthYearDate = as.yearmon(Date),
      MonthYear = factor(format(MonthYearDate, "%b %Y"),
                         levels = format(sort(unique(MonthYearDate)), "%b %Y"))
    )
  
  # Temporal trend arrow
  tnum <- as.numeric(scores_df$Date)
  fit1 <- lm(NMDS1 ~ tnum, data = scores_df)
  fit2 <- lm(NMDS2 ~ tnum, data = scores_df)
  trend_df <- tibble(
    start_x = predict(fit1, data.frame(tnum = min(tnum))),
    start_y = predict(fit2, data.frame(tnum = min(tnum))),
    end_x   = predict(fit1, data.frame(tnum = max(tnum))),
    end_y   = predict(fit2, data.frame(tnum = max(tnum)))
  )
  
  # Run envfit for species
  fit_species <- envfit(nmds, species_data, permutations = 999)
  arrows_df <- as.data.frame(fit_species$vectors$arrows * fit_species$vectors$r) %>%
    rownames_to_column("Species") %>%
    mutate(
      r = fit_species$vectors$r,
      p = fit_species$vectors$pvals
    ) %>%
    filter(p < 0.05)  # only significant species
  
  # Color palette
  color_palette <- colorRampPalette(c("red", "blue"))(length(levels(scores_df$MonthYear)))
  catchment_name <- catchment_lookup[site_name] %>% replace_na("Unknown")
  
  # Plot
  p <- ggplot(scores_df, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = Period)) +
    geom_point(size = 3) +
    geom_segment(
      data = trend_df,
      aes(x = start_x, y = start_y, xend = end_x, yend = end_y),
      arrow = arrow(type = "closed", length = unit(0.15, "inches")),
      inherit.aes = FALSE,
      linewidth = 1, colour = "black"
    ) +
    geom_segment(
      data = arrows_df,
      aes(x = 0, y = 0, xend = NMDS1, yend = NMDS2),
      arrow = arrow(length = unit(0.15, "inches")),
      color = "darkgreen", inherit.aes = FALSE
    ) +
    geom_text_repel(
      data = arrows_df,
      aes(x = NMDS1, y = NMDS2, label = Species),
      color = "darkgreen", size = 3, inherit.aes = FALSE
    ) +
    scale_color_manual(values = color_palette) +
    scale_shape_manual(values = c(16, 17)) +
    theme_minimal(base_size = 14) +
    labs(
      title = paste(catchment_name, "-", site_name),
      x = "NMDS1", y = "NMDS2",
      color = "Sampling Date", shape = "Period"
    ) +
    theme(legend.position = "right", legend.key.size = unit(0.6, "cm"))
  
  list(plot = p, stress = nmds$stress)
}

# Loop through sites and save plots
stress_results <- tibble(Site = character(), Stress = numeric())

for (site in unique(macrospecies$Site)) {
  message("Processing site: ", site)
  result <- plot_site_nmds(filter(macrospecies, Site == site), site)
  if (!is.null(result)) {
    jpeg(paste0(gsub(" ", "_", site), "_NMDS.jpeg"), width = 8, height = 6, units = "in", res = 300)
    print(result$plot)
    dev.off()
    
    stress_results <- bind_rows(stress_results, tibble(Site = site, Stress = result$stress))
  }
}

print(stress_results)




### Top species and abundance change.

# Prepare community matrix (samples x species)
community_matrix <- macrospeciesmean_all %>%
  unite("SampleID", Site, Phase, Date, remove = FALSE) %>%
  select(SampleID, Species, Tally) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0) %>%
  column_to_rownames("SampleID")

# Metadata with Site and Phase per sample
metadata <- macrospeciesmean_all %>%
  unite(SampleID, Site, Phase, Date, remove = FALSE) %>%
  distinct(SampleID, Site, Phase) %>%
  column_to_rownames("SampleID")

# Run NMDS on entire dataset
set.seed(123)
nmds <- metaMDS(community_matrix, distance = "bray", k = 2, trymax = 100)

# Fit species vectors on NMDS (whole dataset)
fit <- envfit(nmds, community_matrix, permutations = 999)

# Extract species vectors and p-values (whole dataset)
species_scores <- as.data.frame(fit$vectors$arrows * fit$vectors$r) %>%
  rownames_to_column("Species") %>%
  mutate(r = fit$vectors$r,
         p = fit$vectors$pvals) %>%
  arrange(desc(r))

# Run NMDS + envfit for each Site separately
sites <- unique(metadata$Site)
results_list <- list()

for (s in sites) {
  samples_s <- rownames(metadata)[metadata$Site == s]
  comm_s <- community_matrix[samples_s, , drop = FALSE]
  
  if (nrow(comm_s) <= 2) {
    message("Skipping site ", s, ": not enough samples (", nrow(comm_s), ") for NMDS k=2")
    next
  }
  
  set.seed(123)
  nmds_s <- metaMDS(comm_s, distance = "bray", k = 2, trymax = 100, autotransform = FALSE, trace = FALSE)
  
  fit_s <- envfit(nmds_s, comm_s, permutations = 999)
  
  df_s <- as.data.frame(fit_s$vectors$arrows * fit_s$vectors$r) %>%
    tibble::rownames_to_column("Species") %>%
    mutate(r = fit_s$vectors$r,
           p = fit_s$vectors$pvals,
           Site = s) %>%
    arrange(desc(r))
  
  results_list[[s]] <- df_s
}

species_drivers <- bind_rows(results_list)

# Filter significant species per Site (p < 0.05)
species_drivers_sig <- species_drivers %>%
  filter(p < 0.05)

species_drivers_sig <- species_drivers_sig %>%
  mutate(Site = case_when(
    Site == "EM1" ~ "EM1 Control",
    Site == "EM4" ~ "EM4 Control",
    Site == "EM5" ~ "EM5 Control",
    TRUE ~ Site
  ))

# Calculate abundance change per species per Site (Construction minus Baseline)
abundance_change <- macrospecies %>%
  group_by(Site, Phase, Species) %>%
  summarise(mean_Tally = mean(Tally), .groups = "drop") %>%
  pivot_wider(names_from = Phase, values_from = mean_Tally, values_fill = 0) %>%
  mutate(Change = `Routine Construction` - Baseline) %>%
  arrange(desc(abs(Change)))

# View top species driving NMDS shifts with significant envfit and abundance changes
topspecies_individualsites <- left_join(species_drivers_sig, abundance_change, by = c("Site", "Species")) %>%
  arrange(Site, desc(abs(Change)))

write.xlsx(topspecies_individualsites, 'topspecies_individualsites.xlsx')





### Plots with arrows, hulls, and labels

# Preprocess data
macrospecies <- macrospecies %>%
  mutate(
    Date = as.Date(Date),
    Site = case_when(
      Site == "EM1" ~ "EM1 Control",
      Site == "EM4" ~ "EM4 Control",
      Site == "EM5" ~ "EM5 Control",
      TRUE ~ Site
    ),
    Catchment = case_when(
      Site %in% c("EM4 Control", "EM5 Control", "EM7", "EM8") ~ "Mimi",
      Site %in% c("EM1 Control", "EM2", "EM3") ~ "Mangapēpeke",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!grepl("^MMA", Site))

catchment_lookup <- setNames(macrospecies$Catchment, macrospecies$Site)

# Prepare community matrix and metadata
community_matrix <- macrospeciesmean_all %>%
  unite("SampleID", Site, Phase, Date, remove = FALSE) %>%
  select(SampleID, Species, Tally) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0) %>%
  column_to_rownames("SampleID")

metadata <- macrospeciesmean_all %>%
  unite("SampleID", Site, Phase, Date, remove = FALSE) %>%
  distinct(SampleID, Site, Phase) %>%
  column_to_rownames("SampleID")

# Run NMDS + envfit per site to identify top species
sites <- unique(metadata$Site)
results_list <- list()

for (s in sites) {
  samples_s <- rownames(metadata)[metadata$Site == s]
  comm_s <- community_matrix[samples_s, , drop = FALSE]
  
  if (nrow(comm_s) <= 2) next
  
  set.seed(123)
  nmds_s <- metaMDS(comm_s, distance = "bray", k = 2, trymax = 100, autotransform = FALSE, trace = FALSE)
  fit_s <- envfit(nmds_s, comm_s, permutations = 999)
  
  df_s <- as.data.frame(fit_s$vectors$arrows * fit_s$vectors$r) %>%
    tibble::rownames_to_column("Species") %>%
    mutate(r = fit_s$vectors$r,
           p = fit_s$vectors$pvals,
           Site = s) %>%
    filter(p < 0.05)   # keep only significant species
  
  results_list[[s]] <- df_s
}

species_drivers_sig <- bind_rows(results_list) %>%
  mutate(Site = case_when(
    Site == "EM1" ~ "EM1 Control",
    Site == "EM4" ~ "EM4 Control",
    Site == "EM5" ~ "EM5 Control",
    TRUE ~ Site
  ))

# Select top 10 species per site
topspecies_individualsites <- species_drivers_sig %>%
  group_by(Site) %>%
  arrange(desc(abs(r))) %>%
  slice_head(n = 10) %>%
  ungroup()

# NMDS plotting function with species points
plot_site_nmds <- function(site_data, site_name, topspecies_df, species_scale = 1.5) {
  
  macro_site <- site_data %>%
    group_by(Site, Date, Species) %>%
    summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop") %>%
    unite("SampleID", Site, Date, remove = FALSE) %>%
    pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)
  
  species_data <- macro_site %>% select(-SampleID, -Site, -Date)
  if (nrow(species_data) <= 2) return(NULL)
  
  set.seed(123)
  nmds <- metaMDS(species_data, distance = "bray", k = 2, trymax = 100)
  
  # Site scores
  scores_df <- as.data.frame(scores(nmds, display = "sites"))
  scores_df$Site <- macro_site$Site
  scores_df$Date <- as.Date(macro_site$Date)
  scores_df <- scores_df %>%
    arrange(Date) %>%
    mutate(
      Period = if_else(Date < as.Date("2022-07-01"), "Baseline", "Construction"),
      MonthYearDate = as.yearmon(Date),
      MonthYear = factor(format(MonthYearDate, "%b %Y"),
                         levels = format(sort(unique(MonthYearDate)), "%b %Y"))
    )
  
  # Temporal trend arrow
  tnum <- as.numeric(scores_df$Date)
  fit1 <- lm(NMDS1 ~ tnum, data = scores_df)
  fit2 <- lm(NMDS2 ~ tnum, data = scores_df)
  trend_df <- tibble(
    start_x = predict(fit1, data.frame(tnum = min(tnum))),
    start_y = predict(fit2, data.frame(tnum = min(tnum))),
    end_x   = predict(fit1, data.frame(tnum = max(tnum))),
    end_y   = predict(fit2, data.frame(tnum = max(tnum)))
  )
  
  # Get top species for this site
  arrows_df <- topspecies_df %>%
    filter(Site == site_name) %>%
    mutate(
      NMDS1 = NMDS1 * species_scale,
      NMDS2 = NMDS2 * species_scale
    )
  
  # Create convex hulls for Baseline and Construction
  hulls_df <- scores_df %>%
    group_by(Period) %>%
    slice(chull(NMDS1, NMDS2)) %>%
    ungroup()
  
  # Color palette
  color_palette <- colorRampPalette(c("red", "blue"))(length(levels(scores_df$MonthYear)))
  catchment_name <- catchment_lookup[site_name] %>% replace_na("Unknown")
  
  # Plot
  p <- ggplot() +
    geom_polygon(data = hulls_df, aes(x = NMDS1, y = NMDS2, fill = Period),
                 alpha = 0.25, color = NA) +
    geom_point(data = scores_df, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = Period), size = 3) +
    geom_segment(
      data = trend_df,
      aes(x = start_x, y = start_y, xend = end_x, yend = end_y),
      arrow = arrow(type = "closed", length = unit(0.15, "inches")),
      inherit.aes = FALSE,
      linewidth = 1, colour = "black"
    ) +
    geom_point(
      data = arrows_df,
      aes(x = NMDS1, y = NMDS2),
      color = "darkgreen", size = 2, inherit.aes = FALSE
    ) +
    geom_text_repel(
      data = arrows_df,
      aes(x = NMDS1, y = NMDS2, label = Species),
      color = "darkgreen", size = 3, inherit.aes = FALSE
    ) +
    scale_color_manual(values = color_palette) +
    scale_shape_manual(values = c(16, 17)) +
    scale_fill_manual(values = c("Baseline" = "lightpink", "Construction" = "lightblue")) +
    theme_minimal(base_size = 14) +
    labs(
      title = paste(catchment_name, "-", site_name),
      x = "NMDS1", y = "NMDS2",
      color = "Sampling Date", shape = "Period", fill = "Period"
    ) +
    theme(legend.position = "right", legend.key.size = unit(0.6, "cm"))
  
  list(plot = p, stress = nmds$stress)
}

# Loop through sites and save plots
stress_results <- tibble(Site = character(), Stress = numeric())

for (site in unique(macrospecies$Site)) {
  message("Processing site: ", site)
  result <- plot_site_nmds(filter(macrospecies, Site == site), site, topspecies_individualsites)
  if (!is.null(result)) {
    jpeg(paste0(gsub(" ", "_", site), "_NMDS.jpeg"), width = 8, height = 6, units = "in", res = 300)
    print(result$plot)
    dev.off()
    
    stress_results <- bind_rows(stress_results, tibble(Site = site, Stress = result$stress))
  }
}

print(stress_results)











# Extracting significant species from NMDS for each catchment

# Define catchments by their sites
catchment_sites <- list(
  Mangapepeke = c("EM2", "EM3"),
  Mimi = c("EM4", "EM7", "EM8")
)

results_list <- list()

for (catchment_name in names(catchment_sites)) {
  sites_in_catchment <- catchment_sites[[catchment_name]]
  
  # Find sample rownames that contain any of the sites in this catchment
  samples_subset <- rownames(community_matrix)[
    sapply(rownames(community_matrix), function(x) any(str_detect(x, sites_in_catchment)))
  ]
  
  # Subset community matrix for those samples
  comm_subset <- community_matrix[samples_subset, , drop = FALSE]
  
  # Replace NAs with zero if any
  comm_subset[is.na(comm_subset)] <- 0
  
  # Remove samples with zero sum to avoid NMDS errors
  comm_subset <- comm_subset[rowSums(comm_subset) > 0, ]
  
  # Check if enough samples to run NMDS
  if (nrow(comm_subset) <= 2) {
    message("Skipping catchment ", catchment_name, ": not enough samples (", nrow(comm_subset), ") for NMDS k=2")
    next
  }
  
  set.seed(123)
  nmds <- metaMDS(comm_subset, distance = "bray", k = 2, trymax = 100, autotransform = FALSE, trace = FALSE)
  
  fit <- envfit(nmds, comm_subset, permutations = 999)
  
  df_fit <- as.data.frame(fit$vectors$arrows * fit$vectors$r) %>%
    rownames_to_column("Species") %>%
    mutate(r = fit$vectors$r,
           p = fit$vectors$pvals,
           Catchment = catchment_name) %>%
    arrange(desc(r))
  
  results_list[[catchment_name]] <- df_fit
}

# Combine all catchment results into one dataframe
species_drivers <- bind_rows(results_list)

# Filter significant species
species_drivers_sig <- species_drivers %>% filter(p < 0.05)

species_drivers_sig

write.xlsx(species_drivers_sig, 'species_drivers_sig.xlsx')

