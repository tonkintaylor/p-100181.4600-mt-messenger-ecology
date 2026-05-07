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







#Species importance - split by catchment
species_data_all_1_3 <- macro_matrix_all %>%
  filter(Site %in% c("EM1", "EM2","EM3"))%>%
  select(-SampleID, -Site, -Date)
species_data_all_4_7_8 <- macro_matrix_all %>%
  filter(Site %in% c("EM4","EM7","EM8"))%>%
  select(-SampleID, -Site, -Date)

isa_result_1_3 <- multipatt(species_data_all_1_3, grouping_factor_1_2_3, func = "IndVal.g", control = how(nperm = 999))
summary(isa_result_1_3)
isa_result_1_3_summary <- as.data.frame(isa_result_1_3[["sign"]])

isa_result_4_7_8 <- multipatt(species_data_all_4_7_8, grouping_factor_4_7_8, func = "IndVal.g", control = how(nperm = 999))
summary(isa_result_4_7_8)
isa_result_4_7_8_summary <- as.data.frame(isa_result_4_7_8[["sign"]])

# Extract and filter significant species
important_species_13 <- isa_result_1_3_summary %>%
  rownames_to_column("Species") %>%
  filter(p.value < 0.05) %>%
  pivot_longer(cols = starts_with("s."), names_to = "SiteGroup", values_to = "presence") %>%
  filter(presence == 1) %>%
  select(Species, SiteGroup, stat, p.value) %>%
  mutate(
    SiteGroup = gsub("^s\\.", "", SiteGroup),
    Species = fct_reorder(Species, stat)
  )
important_species_478 <- isa_result_4_7_8_summary %>%
  rownames_to_column("Species") %>%
  filter(p.value < 0.05) %>%
  pivot_longer(cols = starts_with("s."), names_to = "SiteGroup", values_to = "presence") %>%
  filter(presence == 1) %>%
  select(Species, SiteGroup, stat, p.value) %>%
  mutate(
    SiteGroup = gsub("^s\\.", "", SiteGroup),
    Species = fct_reorder(Species, stat)
  )

#Export importance table
important_species_filtered_13 <- important_species_13 %>%
  mutate(SiteGroup = factor(SiteGroup, levels = sort(unique(SiteGroup))))
important_species_filtered_478 <- important_species_478 %>%
  mutate(SiteGroup = factor(SiteGroup, levels = sort(unique(SiteGroup))))

write.xlsx(important_species_filtered_13, 'significant_species_importance_13.xlsx')
write.xlsx(important_species_filtered_478, 'significant_species_importance_4578.xlsx')

# Plot 1: EM1, EM2, EM3
plot1 <- ggplot(important_species_filtered_13, aes(x = Species, y = stat, fill = SiteGroup)) +
  geom_col(position = "dodge", width = 0.7) +
  labs(
    title = "Indicator Species (Mangapēpeke Sites) - p < 0.05",
    x = "Species",
    y = "Indicator Value",
    fill = "Sites"
  ) +
  coord_flip() +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.y = element_text(face = "italic"),
    plot.title = element_text(face = "bold")
  )

# Plot 2: EM4, EM7, EM8
plot2 <- ggplot(important_species_filtered_478, aes(x = Species, y = stat, fill = SiteGroup)) +
  geom_col(position = "dodge", width = 0.7) +
  labs(
    title = "Indicator Species (Mimi Sites) - p < 0.05",
    x = "Species",
    y = "Indicator Value",
    fill = "Sites"
  ) +
  coord_flip() +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.y = element_text(face = "italic"),
    plot.title = element_text(face = "bold")
  )

















#Species importance - all
isa_result <- multipatt(species_data_all, grouping_factor, func = "IndVal.g", control = how(nperm = 999))
summary(isa_result)
isa_summary <- as.data.frame(isa_result[["sign"]])

# Extract and filter significant species
important_species <- isa_summary %>%
  rownames_to_column("Species") %>%
  filter(p.value < 0.05) %>%
  pivot_longer(cols = starts_with("s."), names_to = "SiteGroup", values_to = "presence") %>%
  filter(presence == 1) %>%
  select(Species, SiteGroup, stat, p.value) %>%
  mutate(
    SiteGroup = gsub("^s\\.", "", SiteGroup),
    Species = fct_reorder(Species, stat)
  )

# Remove MMA 6 and MMA 6b from the data
important_species_filtered <- important_species %>%
  filter(!SiteGroup %in% c("MMA 6", "MMA 6b")) %>%
  mutate(SiteGroup = factor(SiteGroup, levels = sort(unique(SiteGroup))))

#Export importance table
write.xlsx(important_species_filtered, 'significant_species_importance.xlsx')

# Plot with fill by SiteGroup
ggplot(important_species_filtered, aes(x = Species, y = stat, fill = SiteGroup)) +
  geom_col(position = "dodge", width = 0.7) +
  labs(
    title = "Indicator Species (p < 0.05)",
    x = "Species",
    y = "Indicator Value",
    fill = "Site Group"
  ) +
  coord_flip() +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.y = element_text(face = "italic"),
    plot.title = element_text(face = "bold")
  )

# Subset the data for the first plot (EM1, EM2, EM3)
important_species_em1_em3 <- important_species %>%
  filter(SiteGroup %in% c("EM1", "EM2", "EM3")) %>%
  mutate(SiteGroup = factor(SiteGroup, levels = sort(unique(SiteGroup))))  # Alphabetical order for SiteGroup

# Plot 1: EM1, EM2, EM3
plot1 <- ggplot(important_species_em1_em3, aes(x = Species, y = stat, fill = SiteGroup)) +
  geom_col(position = "dodge", width = 0.7) +
  labs(
    title = "Indicator Species (EM1, EM2, EM3) - p < 0.05",
    x = "Species",
    y = "Indicator Value",
    fill = "Site Group"
  ) +
  coord_flip() +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.y = element_text(face = "italic"),
    plot.title = element_text(face = "bold")
  )

# Subset the data for the second plot (EM4, EM7, EM8)
important_species_em4_em8 <- important_species %>%
  filter(SiteGroup %in% c("EM4", "EM7", "EM8")) %>%
  mutate(SiteGroup = factor(SiteGroup, levels = sort(unique(SiteGroup))))  # Alphabetical order for SiteGroup

# Plot 2: EM4, EM7, EM8
plot2 <- ggplot(important_species_em4_em8, aes(x = Species, y = stat, fill = SiteGroup)) +
  geom_col(position = "dodge", width = 0.7) +
  labs(
    title = "Indicator Species (EM4, EM7, EM8) - p < 0.05",
    x = "Species",
    y = "Indicator Value",
    fill = "Site Group"
  ) +
  coord_flip() +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.y = element_text(face = "italic"),
    plot.title = element_text(face = "bold")
  )










#All NMDS
macrospeciesmean_all <- macrospecies %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")

macro_matrix_all <- macrospeciesmean_all %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)%>% 
  filter(!grepl("^MMA", Site))

species_data_all <- macro_matrix_all %>% select(-SampleID, -Site, -Date)
macro_NMDS_all <- metaMDS(species_data_all, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_all$stress)

nmds_scores_all <- as.data.frame(scores(macro_NMDS_all, display = "sites"))
nmds_scores_species_all <- as.data.frame(scores(macro_NMDS_all, display = "species"))

nmds_scores_all$Site <- macro_matrix_all$Site
nmds_scores_all$Date <- macro_matrix_all$Date

# Ensure Date is in proper format
nmds_scores_all <- nmds_scores_all %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),
    SiteGroup = Site,
    MonthYearDate = as.yearmon(Date),  # Proper date object for monthly grouping
    MonthYear = format(MonthYearDate, "%b %Y"),
    MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
  )

#Generate red-to-blue palette matching the time order
color_palette_all <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_all$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_all$Species <- rownames(nmds_scores_species_all)
nmds_scores_species_all$Influence <- sqrt(nmds_scores_species_all$NMDS1^2 + nmds_scores_species_all$NMDS2^2)

# Select top 20 most influential species
top_species_all <- nmds_scores_species_all %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 20)

# Compute convex hulls for each SiteGroup
hull_data_all <- nmds_scores_all %>%
  group_by(SiteGroup) %>%
  slice(chull(NMDS1, NMDS2))  # convex hull points

# Plot
ggplot(nmds_scores_all, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  # Add hull polygons
  geom_polygon(data = hull_data_all,
               aes(x = NMDS1, y = NMDS2, fill = SiteGroup, group = SiteGroup),
               color = "black", alpha = 0.2, inherit.aes = FALSE) +
  
  geom_point(size = 3, stroke = 1.1) +
#  geom_text_repel(data = top_species_all,
#                  aes(x = NMDS1, y = NMDS2, label = Species),
#                  size = 3,
#                  color = "black",
#                  max.overlaps = Inf,
#                  box.padding = 0.4,
#                  point.padding = 0.2,
#                  segment.color = "grey50",
#                  inherit.aes = FALSE) +
  scale_color_manual(values = color_palette_all) +
  scale_shape_manual(values = c(16, 17, 15, 3, 4, 8, 11, 9, 10)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Sampling Date",
    shape = "Site",
    fill = "Site"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )












#Baseline NMDS
macrospeciesmean_base <- macrospecies %>%
  filter(Phase == "Baseline") %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")

macro_matrix_base <- macrospeciesmean_base %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_base <- macro_matrix_base %>% select(-SampleID, -Site, -Date)
macro_NMDS_base <- metaMDS(species_data_base, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_base$stress)

nmds_scores_base <- as.data.frame(scores(macro_NMDS_base, display = "sites"))
nmds_scores_species_base <- as.data.frame(scores(macro_NMDS_base, display = "species"))

nmds_scores_base$Site <- macro_matrix_base$Site
nmds_scores_base$Date <- macro_matrix_base$Date

# Ensure Date is in proper format
nmds_scores_base <- nmds_scores_base %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),  # Format dates as "dd/mm/yyyy"
    SiteGroup = Site,                       # Use your own grouping if needed
    MonthYear = format(as.Date(Date), "%b %Y"),  # e.g. "Apr 2025"
    MonthYear = factor(MonthYear, levels = unique(MonthYear))  # preserve order
  )

#Generate red-to-blue palette matching the time order
color_palette_base <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_base$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_base$Species <- rownames(nmds_scores_species_base)
nmds_scores_species_base$Influence <- sqrt(nmds_scores_species_base$NMDS1^2 + nmds_scores_species_base$NMDS2^2)

# Select top 10 most influential species
top_species_base <- nmds_scores_species_base %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 10)

# Plot
ggplot(nmds_scores_base, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  geom_point(size = 3, stroke = 1.1) +
#geom_text_repel(data = top_species_base,
#                aes(x = NMDS1, y = NMDS2, label = Species),
#                size = 3,
#                color = "black",
#                max.overlaps = Inf,
#                box.padding = 0.4,
#                point.padding = 0.2,
#                segment.color = "grey50",
#                inherit.aes = FALSE)  +
  scale_color_manual(values = color_palette_base) +
  scale_shape_manual(values = c(16, 17, 15, 3, 4, 8)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Baseline Sampling Date",
    shape = "Site"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )




#Construction NMDS
macrospeciesmean_construction <- macrospecies %>%
  filter(Phase == "Routine Construction") %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")

macro_matrix_construction <- macrospeciesmean_construction %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_construction <- macro_matrix_construction %>% select(-SampleID, -Site, -Date)
macro_NMDS_construction <- metaMDS(species_data_construction, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_construction$stress)


nmds_scores_construction <- as.data.frame(scores(macro_NMDS_construction, display = "sites"))
nmds_scores_species_construction <- as.data.frame(scores(macro_NMDS_construction, display = "species"))

nmds_scores_construction$Site <- macro_matrix_construction$Site
nmds_scores_construction$Date <- macro_matrix_construction$Date

# Ensure Date is in proper format
nmds_scores_construction <- nmds_scores_construction %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),
    SiteGroup = Site,
    MonthYearDate = as.yearmon(Date),  # Proper date object for monthly grouping
    MonthYear = format(MonthYearDate, "%b %Y"),
    MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
  )

#Generate red-to-blue palette matching the time order
color_palette_construction <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_construction$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_construction$Species <- rownames(nmds_scores_species_construction)
nmds_scores_species_construction$Influence <- sqrt(nmds_scores_species_construction$NMDS1^2 + nmds_scores_species_construction$NMDS2^2)

# Select top 10 most influential species
top_species_construction <- nmds_scores_species_construction %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 10)

# Plot
ggplot(nmds_scores_construction, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  geom_point(size = 3, stroke = 1.1) +
#  geom_text_repel(data = top_species_construction,
#                  aes(x = NMDS1, y = NMDS2, label = Species),
#                  size = 3,
#                  color = "black",
#                  max.overlaps = Inf,
#                  box.padding = 0.4,
#                  point.padding = 0.2,
#                  segment.color = "grey50",
#                  inherit.aes = FALSE)  +
  scale_color_manual(values = color_palette_construction) +
  scale_shape_manual(values = c(16, 17, 15, 3, 4, 8, 11)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Construction Sampling Date",
    shape = "Site"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )












#Mangapepeke NMDS
macrospeciesmean_mang <- macrospecies %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop") %>%
  filter(Site %in% c("EM1", "EM2", "EM3", "EM5")) %>%
  mutate(Site = ifelse(Site == "EM1", "EM1 Control", Site)) %>%
  mutate(Site = ifelse(Site == "EM5", "EM5 Control", Site))


macro_matrix_mang <- macrospeciesmean_mang %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_mang <- macro_matrix_mang %>% select(-SampleID, -Site, -Date)
macro_NMDS_mang <- metaMDS(species_data_mang, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_mang$stress)

nmds_scores_mang <- as.data.frame(scores(macro_NMDS_mang, display = "sites"))
nmds_scores_species_mang <- as.data.frame(scores(macro_NMDS_mang, display = "species"))

nmds_scores_mang$Site <- macro_matrix_mang$Site
nmds_scores_mang$Date <- macro_matrix_mang$Date

# Ensure Date is in proper format
nmds_scores_mang <- nmds_scores_mang %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),
    SiteGroup = Site,
    MonthYearDate = as.yearmon(Date),  # Proper date object for monthly grouping
    MonthYear = format(MonthYearDate, "%b %Y"),
    MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
  )

#Generate red-to-blue palette matching the time order
color_palette_mang <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_mang$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_mang$Species <- rownames(nmds_scores_species_mang)
nmds_scores_species_mang$Influence <- sqrt(nmds_scores_species_mang$NMDS1^2 + nmds_scores_species_mang$NMDS2^2)

# Select top 20 most influential species
top_species_mang <- nmds_scores_species_mang %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 20)

# Compute convex hulls for each SiteGroup
hull_data_mang <- nmds_scores_mang %>%
  group_by(SiteGroup) %>%
  slice(chull(NMDS1, NMDS2))  # convex hull points

# Plot
ggplot(nmds_scores_mang, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  # Add hull polygons
  geom_polygon(data = hull_data_mang,
               aes(x = NMDS1, y = NMDS2, fill = SiteGroup, group = SiteGroup),
               color = "black", alpha = 0.2, inherit.aes = FALSE) +
  
  geom_point(size = 3, stroke = 1.1) +
#  geom_text_repel(data = top_species_mang,
#                  aes(x = NMDS1, y = NMDS2, label = Species),
#                  size = 3,
#                  color = "black",
#                  max.overlaps = Inf,
#                  box.padding = 0.4,
#                  point.padding = 0.2,
#                  segment.color = "grey50",
#                  inherit.aes = FALSE) +
  scale_color_manual(values = color_palette_mang) +
  scale_shape_manual(values = c(16, 17, 15, 3, 4, 8, 11, 9, 10)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Sampling Date",
    shape = "Mangapēpeke Sites",
    fill = "Mangapēpeke Sites"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )




#Mimi NMDS
macrospeciesmean_mimi <- macrospecies %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop") %>%
  filter(Site %in% c("EM4", "EM5", "EM7", "EM8"))%>%
  mutate(Site = ifelse(Site == "EM4", "EM4 Control", Site))%>%
  mutate(Site = ifelse(Site == "EM5", "EM5 Control", Site))

macro_matrix_mimi <- macrospeciesmean_mimi %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_mimi <- macro_matrix_mimi %>% select(-SampleID, -Site, -Date)
macro_NMDS_mimi <- metaMDS(species_data_mimi, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_mimi$stress)

nmds_scores_mimi <- as.data.frame(scores(macro_NMDS_mimi, display = "sites"))
nmds_scores_species_mimi <- as.data.frame(scores(macro_NMDS_mimi, display = "species"))

nmds_scores_mimi$Site <- macro_matrix_mimi$Site
nmds_scores_mimi$Date <- macro_matrix_mimi$Date

# Ensure Date is in proper format
nmds_scores_mimi <- nmds_scores_mimi %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),
    SiteGroup = Site,
    MonthYearDate = as.yearmon(Date),  # Proper date object for monthly grouping
    MonthYear = format(MonthYearDate, "%b %Y"),
    MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
  )

#Generate red-to-blue palette matching the time order
color_palette_mimi <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_mimi$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_mimi$Species <- rownames(nmds_scores_species_mimi)
nmds_scores_species_mimi$Influence <- sqrt(nmds_scores_species_mimi$NMDS1^2 + nmds_scores_species_mimi$NMDS2^2)

# Select top 20 most influential species
top_species_mimi <- nmds_scores_species_mimi %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 20)

# Compute convex hulls for each SiteGroup
hull_data <- nmds_scores_mimi %>%
  group_by(SiteGroup) %>%
  slice(chull(NMDS1, NMDS2))  # convex hull points

# Plot
ggplot(nmds_scores_mimi, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  # Add hull polygons
  geom_polygon(data = hull_data,
               aes(x = NMDS1, y = NMDS2, fill = SiteGroup, group = SiteGroup),
               color = "black", alpha = 0.2, inherit.aes = FALSE) +
  
  geom_point(size = 3, stroke = 1.1) +
#  geom_text_repel(data = top_species_mimi,
#                  aes(x = NMDS1, y = NMDS2, label = Species),
#                  size = 3,
#                  color = "black",
#                  max.overlaps = Inf,
#                  box.padding = 0.4,
#                  point.padding = 0.2,
#                  segment.color = "grey50",
#                  inherit.aes = FALSE) +
  scale_color_manual(values = color_palette_mimi) +
  scale_shape_manual(values = c(16, 3, 17, 15, 4, 8, 11, 9, 10)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Sampling Date",
    shape = "Mimi Site",
    fill = "Mimi Site"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )




#Soft NMDS
macrospeciesmean_soft <- macrospecies %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop") %>%
  filter(Site %in% c("EM1", "EM2", "EM4", "EM8"))%>%
  mutate(Site = ifelse(Site == "EM1", "EM1 Control", Site))%>%
  mutate(Site = ifelse(Site == "EM4", "EM4 Control", Site))

macro_matrix_soft <- macrospeciesmean_soft %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_soft <- macro_matrix_soft %>% select(-SampleID, -Site, -Date)
macro_NMDS_soft <- metaMDS(species_data_soft, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_soft$stress)

nmds_scores_soft <- as.data.frame(scores(macro_NMDS_soft, display = "sites"))
nmds_scores_species_soft <- as.data.frame(scores(macro_NMDS_soft, display = "species"))

nmds_scores_soft$Site <- macro_matrix_soft$Site
nmds_scores_soft$Date <- macro_matrix_soft$Date

# Ensure Date is in proper format
nmds_scores_soft <- nmds_scores_soft %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),
    SiteGroup = Site,
    MonthYearDate = as.yearmon(Date),  # Proper date object for monthly grouping
    MonthYear = format(MonthYearDate, "%b %Y"),
    MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
  )

#Generate red-to-blue palette matching the time order
color_palette_soft <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_soft$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_soft$Species <- rownames(nmds_scores_species_soft)
nmds_scores_species_soft$Influence <- sqrt(nmds_scores_species_soft$NMDS1^2 + nmds_scores_species_soft$NMDS2^2)

# Select top 20 most influential species
top_species_soft <- nmds_scores_species_soft %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 20)

# Compute convex hulls for each SiteGroup
hull_data <- nmds_scores_soft %>%
  group_by(SiteGroup) %>%
  slice(chull(NMDS1, NMDS2))  # convex hull points

# Plot
ggplot(nmds_scores_soft, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  # Add hull polygons
  geom_polygon(data = hull_data,
               aes(x = NMDS1, y = NMDS2, fill = SiteGroup, group = SiteGroup),
               color = "black", alpha = 0.2, inherit.aes = FALSE) +
  
  geom_point(size = 3, stroke = 1.1) +
#  geom_text_repel(data = top_species_soft,
#                  aes(x = NMDS1, y = NMDS2, label = Species),
#                  size = 3,
#                  color = "black",
#                  max.overlaps = Inf,
#                  box.padding = 0.4,
#                  point.padding = 0.2,
#                  segment.color = "grey50",
#                  inherit.aes = FALSE) +
  scale_color_manual(values = color_palette_soft) +
  scale_shape_manual(values = c(16, 17, 15, 4, 8, 11, 9, 10)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Sampling Date",
    shape = "Soft-bottom Site",
    fill = "Soft-bottom Site"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )

#Hard NMDS
macrospeciesmean_hard <- macrospecies %>%
  group_by(Site, Date, Species) %>%
  summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop") %>%
  filter(Site %in% c("EM3", "EM5 Control", "EM7"))

macro_matrix_hard <- macrospeciesmean_hard %>%
  unite("SampleID", Site, Date, remove = FALSE) %>%
  pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)

species_data_hard <- macro_matrix_hard %>% select(-SampleID, -Site, -Date)
macro_NMDS_hard <- metaMDS(species_data_hard, distance = "bray", k = 2, trymax = 100)
print(macro_NMDS_hard$stress)

nmds_scores_hard <- as.data.frame(scores(macro_NMDS_hard, display = "sites"))
nmds_scores_species_hard <- as.data.frame(scores(macro_NMDS_hard, display = "species"))

nmds_scores_hard$Site <- macro_matrix_hard$Site
nmds_scores_hard$Date <- macro_matrix_hard$Date

# Ensure Date is in proper format
nmds_scores_hard <- nmds_scores_hard %>%
  mutate(
    Date = as.Date(Date),
    DateLabel = format(Date, "%d/%m/%Y"),
    SiteGroup = Site,
    MonthYearDate = as.yearmon(Date),  # Proper date object for monthly grouping
    MonthYear = format(MonthYearDate, "%b %Y"),
    MonthYear = factor(MonthYear, levels = format(sort(unique(MonthYearDate)), "%b %Y"))
  )

#Generate red-to-blue palette matching the time order
color_palette_hard <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores_hard$MonthYear)))

# Calculate influence (vector length) for species
nmds_scores_species_hard$Species <- rownames(nmds_scores_species_hard)
nmds_scores_species_hard$Influence <- sqrt(nmds_scores_species_hard$NMDS1^2 + nmds_scores_species_hard$NMDS2^2)

# Select top 20 most influential species
top_species_hard <- nmds_scores_species_hard %>%
  arrange(desc(Influence)) %>%
  slice_head(n = 20)

# Compute convex hulls for each SiteGroup
hull_data <- nmds_scores_hard %>%
  group_by(SiteGroup) %>%
  slice(chull(NMDS1, NMDS2))  # convex hull points

# Plot
ggplot(nmds_scores_hard, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = SiteGroup)) +
  # Add hull polygons
  geom_polygon(data = hull_data,
               aes(x = NMDS1, y = NMDS2, fill = SiteGroup, group = SiteGroup),
               color = "black", alpha = 0.2, inherit.aes = FALSE) +
  
  geom_point(size = 3, stroke = 1.1) +
#  geom_text_repel(data = top_species_hard,
#                  aes(x = NMDS1, y = NMDS2, label = Species),
#                  size = 3,
#                  color = "black",
#                  max.overlaps = Inf,
#                  box.padding = 0.4,
#                  point.padding = 0.2,
#                  segment.color = "grey50",
#                  inherit.aes = FALSE) +
  scale_color_manual(values = color_palette_hard) +
  scale_shape_manual(values = c(16, 17, 15, 4, 8, 11, 9, 10)) +
  theme_minimal(base_size = 14) +
  labs(
    x = "NMDS1", y = "NMDS2",
    color = "Sampling Date",
    shape = "Hard-bottom Site",
    fill = "Hard-bottom Site"
  ) +
  theme(
    legend.position = "right",
    legend.box = "vertical",
    axis.title = element_text(face = "bold"),
    legend.key.size = unit(0.6, "cm"),
    legend.text = element_text(size = 10)
  )










# Individual NMDS plots before and after construction begins
macrospecies$Date <- as.Date(macrospecies$Date)
macrospecies <- macrospecies %>%
  mutate(Catchment = case_when(
    Site %in% c("EM4", "EM7", "EM8") ~ "Mimi",
    Site %in% c("EM1", "EM2", "EM3") ~ "Mangapēpeke",
    TRUE ~ NA_character_
  ))%>% 
  filter(!grepl("^MMA", Site))%>%
  mutate(Site = ifelse(Site == "EM1", "EM1 Control", Site)) %>%
  mutate(Site = ifelse(Site == "EM4", "EM4 Control", Site)) %>%
  mutate(Site = ifelse(Site == "EM5", "EM5 Control", Site))



library(grDevices)  # for jpeg()

# Define a lookup vector for catchments per site (if not already defined)
catchment_lookup <- c(
  "EM4 Control" = "Mimi",
  "EM7" = "Mimi",
  "EM8" = "Mimi",
  "EM1 Control" = "Mangapēpeke",
  "EM2" = "Mangapēpeke",
  "EM3" = "Mangapēpeke"
  # Add other sites if needed
)

stress_results <- data.frame(Site = character(), Stress = numeric(), stringsAsFactors = FALSE)
site_list <- unique(macrospecies$Site)

for (site in site_list) {
  
  message("Processing site: ", site)
  
  # Filter data for site and summarise mean tally per date/species
  macro_site <- macrospecies %>%
    filter(Site == site) %>%
    group_by(Site, Date, Species) %>%
    summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")
  
  # Wide format for NMDS
  macro_matrix <- macro_site %>%
    unite("SampleID", Site, Date, remove = FALSE) %>%
    pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)
  
  species_data <- macro_matrix %>% select(-SampleID, -Site, -Date)
  
  if (nrow(species_data) <= 2) {
    message("Skipping site ", site, ": not enough samples (", nrow(species_data), ") for NMDS k=2")
    next
  }
  
  # Run NMDS
  macro_NMDS <- metaMDS(species_data, distance = "bray", k = 2, trymax = 100)
  
  # Store stress value
  stress_results <- rbind(stress_results, data.frame(Site = site, Stress = macro_NMDS$stress))
  
  # Get NMDS scores for sites
  nmds_scores <- as.data.frame(scores(macro_NMDS, display = "sites"))
  nmds_scores$Site <- macro_matrix$Site
  nmds_scores$Date <- as.Date(macro_matrix$Date)
  
  nmds_scores <- nmds_scores %>%
    arrange(Date) %>%
    mutate(
      Period = if_else(Date < as.Date("2022-07-01"), "Baseline", "Construction"),
      MonthYearDate = as.yearmon(Date),
      MonthYear = factor(format(MonthYearDate, "%b %Y"),
                         levels = format(sort(unique(MonthYearDate)), "%b %Y"))
    )
  
  # Numeric time for regression
  tnum <- as.numeric(nmds_scores$Date)
  
  # Fit linear models for NMDS1 and NMDS2 over time
  fit1 <- lm(NMDS1 ~ tnum, data = nmds_scores)
  fit2 <- lm(NMDS2 ~ tnum, data = nmds_scores)
  
  # Start/end predicted points
  t_min <- min(tnum, na.rm = TRUE)
  t_max <- max(tnum, na.rm = TRUE)
  start_point <- c(
    predict(fit1, newdata = data.frame(tnum = t_min)),
    predict(fit2, newdata = data.frame(tnum = t_min))
  )
  end_point <- c(
    predict(fit1, newdata = data.frame(tnum = t_max)),
    predict(fit2, newdata = data.frame(tnum = t_max))
  )
  
  # Calculate magnitude of change in NMDS space
  arrow_length <- sqrt((end_point[1] - start_point[1])^2 +
                         (end_point[2] - start_point[2])^2)
  
  # Prepare arrow data frame
  trend_df <- tibble::tibble(
    start_x = start_point[1],
    start_y = start_point[2],
    end_x = end_point[1],
    end_y = end_point[2],
    magnitude = arrow_length
  )
  
  # Color palette for points
  color_palette <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores$MonthYear)))
  
  # Get catchment name from lookup, default to "Unknown" if missing
  catchment_name <- catchment_lookup[site]
  if (is.na(catchment_name)) catchment_name <- "Unknown"
  
  # Define filename for JPEG - safe characters only
  filename <- paste0(gsub(" ", "_", catchment_name), "_", gsub(" ", "_", site), ".jpeg")
  
  # Open JPEG device
  jpeg(filename = filename, width = 8, height = 6, units = "in", res = 300)
  
  # Plot NMDS with time-trend arrow and catchment in title
  print(
    ggplot(nmds_scores, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = Period)) +
      geom_point(size = 3) +
      geom_segment(
        data = trend_df,
        aes(x = start_x, y = start_y, xend = end_x, yend = end_y),
        arrow = arrow(type = "closed", length = unit(0.15, "inches")),
        inherit.aes = FALSE,
        linewidth = 1, colour = "black"
      ) +
      scale_color_manual(values = color_palette) +
      scale_shape_manual(values = c(16, 17)) +
      theme_minimal(base_size = 14) +
      labs(
        title = paste(catchment_name, "-", site),
        x = "NMDS1", y = "NMDS2",
        color = "Sampling Date",
        shape = "Period"
      ) +
      theme(
        legend.position = "right",
        legend.key.size = unit(0.6, "cm")
      )
  )
  
  # Close device to save file
  dev.off()
}

# View all stress values
print(stress_results)





# Define a lookup vector for catchments per site
catchment_lookup <- c(
  "EM4 Control" = "Mimi",
  "EM7" = "Mimi",
  "EM8" = "Mimi",
  "EM1 Control" = "Mangapēpeke",
  "EM2" = "Mangapēpeke",
  "EM3" = "Mangapēpeke"
  # Add other sites if needed
)

# Your existing code
stress_results <- data.frame(Site = character(), Stress = numeric(), stringsAsFactors = FALSE)
site_list <- unique(macrospecies$Site)

for (site in site_list) {
  
  message("Processing site: ", site)
  
  # Filter data for site and summarise mean tally per date/species
  macro_site <- macrospecies %>%
    filter(Site == site) %>%
    group_by(Site, Date, Species) %>%
    summarise(Tally = mean(Tally, na.rm = TRUE), .groups = "drop")
  
  # Wide format for NMDS
  macro_matrix <- macro_site %>%
    unite("SampleID", Site, Date, remove = FALSE) %>%
    pivot_wider(names_from = Species, values_from = Tally, values_fill = 0)
  
  species_data <- macro_matrix %>% select(-SampleID, -Site, -Date)
  
  if (nrow(species_data) <= 2) {
    message("Skipping site ", site, ": not enough samples (", nrow(species_data), ") for NMDS k=2")
    next
  }
  
  # Run NMDS
  macro_NMDS <- metaMDS(species_data, distance = "bray", k = 2, trymax = 100)
  
  # Store stress value
  stress_results <- rbind(stress_results, data.frame(Site = site, Stress = macro_NMDS$stress))
  
  # Get NMDS scores for sites
  nmds_scores <- as.data.frame(scores(macro_NMDS, display = "sites"))
  nmds_scores$Site <- macro_matrix$Site
  nmds_scores$Date <- as.Date(macro_matrix$Date)
  
  nmds_scores <- nmds_scores %>%
    arrange(Date) %>%
    mutate(
      Period = if_else(Date < as.Date("2022-07-01"), "Baseline", "Construction"),
      MonthYearDate = as.yearmon(Date),
      MonthYear = factor(format(MonthYearDate, "%b %Y"),
                         levels = format(sort(unique(MonthYearDate)), "%b %Y"))
    )
  
  # Numeric time for regression
  tnum <- as.numeric(nmds_scores$Date)
  
  # Fit linear models for NMDS1 and NMDS2 over time
  fit1 <- lm(NMDS1 ~ tnum, data = nmds_scores)
  fit2 <- lm(NMDS2 ~ tnum, data = nmds_scores)
  
  # Start/end predicted points
  t_min <- min(tnum, na.rm = TRUE)
  t_max <- max(tnum, na.rm = TRUE)
  start_point <- c(
    predict(fit1, newdata = data.frame(tnum = t_min)),
    predict(fit2, newdata = data.frame(tnum = t_min))
  )
  end_point <- c(
    predict(fit1, newdata = data.frame(tnum = t_max)),
    predict(fit2, newdata = data.frame(tnum = t_max))
  )
  
  # Calculate magnitude of change in NMDS space
  arrow_length <- sqrt((end_point[1] - start_point[1])^2 +
                         (end_point[2] - start_point[2])^2)
  
  # Prepare arrow data frame
  trend_df <- tibble::tibble(
    start_x = start_point[1],
    start_y = start_point[2],
    end_x = end_point[1],
    end_y = end_point[2],
    magnitude = arrow_length
  )
  
  # Color palette for points
  color_palette <- colorRampPalette(c("red", "blue"))(length(levels(nmds_scores$MonthYear)))
  
  # Get catchment name from lookup, default to "Unknown" if missing
  catchment_name <- catchment_lookup[site]
  if (is.na(catchment_name)) catchment_name <- "Unknown"
  
  # Plot NMDS with time-trend arrow and catchment in title
  p <- ggplot(nmds_scores, aes(x = NMDS1, y = NMDS2, color = MonthYear, shape = Period)) +
    geom_point(size = 3) +
    geom_segment(
      data = trend_df,
      aes(x = start_x, y = start_y, xend = end_x, yend = end_y),
      arrow = arrow(type = "closed", length = unit(0.15, "inches")),
      inherit.aes = FALSE,
      linewidth = 1.1, colour = "black"
    ) +
    scale_color_manual(values = color_palette) +
    scale_shape_manual(values = c(16, 17)) +
    theme_minimal(base_size = 14) +
    labs(
      title = paste(catchment_name, "-", site),
      x = "NMDS1", y = "NMDS2",
      color = "Sampling Date",
      shape = "Period"
    ) +
    theme(
      legend.position = "right",
      legend.key.size = unit(0.6, "cm")
    )
  
  print(p)
}

# Print all stress values
print(stress_results)



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

