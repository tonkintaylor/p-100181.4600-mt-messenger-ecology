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

# Update file and sheet names to relevant date. Copy excel file from previous quarter and add new data.
sedimentsize <- read_xlsx("Data.xlsx", sheet = "SedimentSize")

sedimentsize_long <- sedimentsize %>%
  pivot_longer(cols = -c(Site, Date, Period, Season), names_to = "Size", values_to = "Percentage")

# Format Date as factor (ordered by date)
sedimentsize_long$Date <- factor(format(sedimentsize_long$Date, "%d/%m/%Y"),
                                 levels = unique(format(as.Date(sedimentsize_long$Date, format = "%d/%m/%Y"), "%d/%m/%Y")))

# Order Size categories
sedimentsize_long$Size <- factor(sedimentsize_long$Size, levels = c(
  "Clay/silt (<0.06 mm)", 
  "Sand (>0.06-2 mm)",
  "Small gravel (>2-8 mm)",
  "Small-med gravel (>8-16 mm)",
  "Med-large gravel (>16-32 mm)",
  "Large gravel (>32-64 mm)",
  "Small cobble (>64-128 mm)",
  "Large cobble (>128-256 mm)",
  "Boulders (>256 mm)",
  "Bedrock"
))


# List of sites
sites <- c("EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8")

for (site in sites) {
  
  # Filter data for each site
  site_data <- sedimentsize_long %>%
    filter(Site == site)
  
  # Create plot
  p <- ggplot(site_data, aes(x = Date, y = Percentage, fill = Size)) +
    geom_col() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    theme_minimal() +
    scale_fill_brewer(palette = "Paired") +  # 12-color palette
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size=11),
      axis.text.y = element_text(size = 11),
      axis.title = element_text(size = 14),
      strip.text = element_text(face = "bold", size = 14),
      legend.text = element_text(size = 11), # Increase legend text size
      legend.title = element_text(size = 14) # Increase legend title size
          ) +
    labs(
      x = "Sampling Date",
      y = "Percentage",
      fill = "Sediment Size",
      title = paste("Sediment Size Distribution for", site)
    ) +
    annotate("segment", x = 6.5, xend = 6.5, y = 0, yend = 100, color = "black", linewidth = 1.5, linetype = 2) +
    annotate("text", x = 6.5, y = 85, label = "Construction Begins", angle = 90, vjust = -0.5, color = "black")
  
  # Create JPEG file for each plot
  jpeg(filename = paste0("SedimentSizeStack_", site, ".jpg"), width = 12, height = 8, units = "in", res = 300)  # Convert cm to inches, 300 dpi resolution
  
  # Print the plot
  print(p)
  
  # Close the JPEG device
  dev.off()
}





# Filter for EM1
data_em1 <- sedimentsize_long %>%
  filter(Site == "EM1")

# Stacked plot
stackplot_em1 <- ggplot(data_em1, aes(x = Date, y = Percentage, fill = Size)) +
  geom_col() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  theme_minimal() +
  scale_fill_brewer(palette = "Set2")+
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    axis.text.y = element_text(size = 10),
    axis.title = element_text(size = 12),
    strip.text = element_text(face = "bold", size = 11)
  ) +
  labs(
    x = "Sampling Date",
    y = "Percentage",
    fill = "Sediment Size",
    title = "Sediment Size Distribution for EM1"
  )

# Save to A3 (portrait)
ggsave("SedimentSizeStack_EM1_A3_DRAFT.pdf", stackplot_em1,
       width = 42, height = 29.7, units = "cm", dpi = 600)








#Stretched vertical bars
# Create plot
verticalplot_em1 <- ggplot(data_em1, aes(x = Size, y = Percentage, fill = Size)) +
  geom_col() +
  facet_wrap(~Date, ncol = 1, strip.position = "right") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    axis.text.y = element_text(size = 10),
    axis.title = element_text(size = 12),
    legend.position = "none",
    strip.text.y.right = element_text(angle = 0, hjust = 0.5),
    strip.placement = "outside",
    panel.spacing.y = unit(3, "lines")  # <- Stretch vertically more
  ) +
  labs(
    x = "Sediment Size Category",
    y = "Percentage",
    title = "Sediment Size Distribution for EM1 (Vertical Bars)"
  )

# Save to A3 (portrait)
ggsave("SedimentSizeVertical_EM1_A3.pdf", verticalplot_em1,
       width = 29.7, height = 42.0, units = "cm", dpi = 600)
