# Update working directory to relevant quarterly folder.
setwd("//ttgroup.local/corporate/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2024-2025 Report/Stats")
library(ggplot2)
library(ggrepel)
library(scales)
library(RColorBrewer)
library(lubridate)
library(dplyr)
library(gridExtra)
library(grid)
library(ggpubr)
library(readxl)
library(cowplot)
library(magrittr)

# Update file and sheet names to relevant date. Copy excel file from previous quarter and add new data.
macro <- read_xlsx("Data.xlsx", sheet = "Macro1")

# Add seasonal date range when required
summer19 <- as.POSIXct(c("1/01/2019","31/03/2019"), format = "%d/%m/%Y")
summer20 <- as.POSIXct(c("1/01/2020","31/03/2020"), format = "%d/%m/%Y")
summer21 <- as.POSIXct(c("1/01/2021","31/03/2021"), format = "%d/%m/%Y")
summer22 <- as.POSIXct(c("1/01/2022","31/03/2022"), format = "%d/%m/%Y")
summer23 <- as.POSIXct(c("1/01/2023","31/03/2023"), format = "%d/%m/%Y")
summer24 <- as.POSIXct(c("1/01/2024","31/03/2024"), format = "%d/%m/%Y")
summer22 <- as.POSIXct(c("1/01/2025","31/03/2025"), format = "%d/%m/%Y")

# Palette triggers
palette.notrigger <- scale_colour_manual(values=c("Baseline" = "#ff9f1c", "Routine Construction" = "#2ec4b6","Incident" = "#e71d36"))

palette.generaltrigger <- scale_colour_manual(values=c("Baseline" = "#ff9f1c", "Routine Construction" = "#2ec4b6","Incident" = "#e71d36","Trigger Level" = "black"),                       
                                              guide = guide_legend(override.aes = list(
                                                linetype = c("blank","blank","blank","solid"),
                                                shape = c(16,16,16,NA))))

palette.generaltrigger.noincident <- scale_colour_manual(values=c("Baseline" = "#ff9f1c", "Routine Construction" = "#2ec4b6","Trigger Level" = "black"),                       
                                                         guide = guide_legend(override.aes = list(
                                                           linetype = c("blank","blank","solid"),
                                                           shape = c(16,16,NA))))

# Add new winter dates and boxes if required. Update date extents for lims and themes.
palette <- scale_colour_manual(values=c("#2ec4b6", "#e71d36", "#ff9f1c", "#073b4c"))
shapepalette <-  scale_shape_manual(values=c(16,1))

#### Macro analysis ###

Date<-as.POSIXct(macro$Date, format="%d/%m/%Y")
macro$Date=Date

# --- plotting limits etc ---
macrolims <- as.POSIXct(c("1/08/2018","1/05/2025"), format = "%d/%m/%Y")

# --- Themes (removed geom_point from theme lists so we can add once per-plot) ---
Theme_QMCI <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),
        plot.title = element_text(size=14,face="bold",hjust = 0.5),
        legend.text = element_text(size=9),
        legend.title = element_blank(),
        axis.text.x = element_text(angle = 90, vjust = -0.5),
        legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2019-01-01"), xmax = as.POSIXct("2019-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2020-01-01"), xmax = as.POSIXct("2020-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2021-01-01"), xmax = as.POSIXct("2021-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2022-01-01"), xmax = as.POSIXct("2022-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2023-01-01"), xmax = as.POSIXct("2023-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2024-01-01"), xmax = as.POSIXct("2024-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2025-01-01"), xmax = as.POSIXct("2025-03-31"), ymin = -Inf, ymax = Inf),
  scale_x_datetime(limits = macrolims, breaks = date_breaks("3 month"), labels = date_format("%b %y")),
  scale_y_continuous(limits = c(0,8)),
  scale_alpha_manual(name = NULL, values = c(1), breaks = c("Baseline \nMonitoring End"),
                     guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",
                                          override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept = as.POSIXct("2022-02-28"), alpha = "Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  ylab("QMCI"), xlab("")
)

Theme_EPTrich <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),
        plot.title = element_text(size=14,face="bold",hjust = 0.5),
        legend.text = element_text(size=9),
        legend.title = element_blank(),
        axis.text.x = element_text(angle = 90, vjust = -0.5),
        legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2019-01-01"), xmax = as.POSIXct("2019-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2020-01-01"), xmax = as.POSIXct("2020-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2021-01-01"), xmax = as.POSIXct("2021-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2022-01-01"), xmax = as.POSIXct("2022-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2023-01-01"), xmax = as.POSIXct("2023-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2024-01-01"), xmax = as.POSIXct("2024-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2025-01-01"), xmax = as.POSIXct("2025-03-31"), ymin = -Inf, ymax = Inf),
  scale_x_datetime(limits = macrolims, breaks = date_breaks("3 month"), labels = date_format("%b %y")),
  scale_y_continuous(limits = c(0,101)),
  scale_alpha_manual(name = NULL, values = c(1), breaks = c("Baseline \nMonitoring End"),
                     guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",
                                          override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept = as.POSIXct("2022-02-28"), alpha = "Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  ylab("%EPT Richness"), xlab("")
)

Theme_EPTabun <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),
        plot.title = element_text(size=14,face="bold",hjust = 0.5),
        legend.text = element_text(size=9),
        legend.title = element_blank(),
        axis.text.x = element_text(angle = 90, vjust = -0.5),
        legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2019-01-01"), xmax = as.POSIXct("2019-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2020-01-01"), xmax = as.POSIXct("2020-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2021-01-01"), xmax = as.POSIXct("2021-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2022-01-01"), xmax = as.POSIXct("2022-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2023-01-01"), xmax = as.POSIXct("2023-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2024-01-01"), xmax = as.POSIXct("2024-03-31"), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct("2025-01-01"), xmax = as.POSIXct("2025-03-31"), ymin = -Inf, ymax = Inf),
  scale_x_datetime(limits = macrolims, breaks = date_breaks("3 month"), labels = date_format("%b %y")),
  scale_y_continuous(limits = c(0,101)),
  scale_alpha_manual(name = NULL, values = c(1), breaks = c("Baseline \nMonitoring End"),
                     guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",
                                          override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept = as.POSIXct("2022-02-28"), alpha = "Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  ylab("%EPT Abundance"), xlab("")
)

# --- Create per-site/date means (this replicates your original averaged dataset behaviour:
#     we average replicates for each Site+Date so each Date is equally weighted when computing triggers) ---
macro_means <- macro %>%
  group_by(Site, Date, Period) %>%
  summarise(
    QMCI = mean(QMCI, na.rm = TRUE),
    EPTrich = mean(EPTrich, na.rm = TRUE),
    EPTabun = mean(EPTabun, na.rm = TRUE),
    .groups = "drop"
  )

# --- Calculate 15% trigger levels from the per-date means (Baseline period) ---
sites_to_do <- unique(macro_means$Site)

for (s in sites_to_do) {
  # QMCI
  base_vals_qmci <- macro_means %>% filter(Site == s, Period == "Baseline") %>% pull(QMCI)
  base_mean_qmci <- if (length(base_vals_qmci) == 0) NA_real_ else mean(base_vals_qmci, na.rm = TRUE)
  assign(paste0(s, ".qmci.trigger"), data.frame(yintercept = ifelse(is.na(base_mean_qmci), NA_real_, base_mean_qmci * 0.85), Lines = "Trigger Level"))

  # EPTrich
  base_vals_eptrich <- macro_means %>% filter(Site == s, Period == "Baseline") %>% pull(EPTrich)
  base_mean_eptrich <- if (length(base_vals_eptrich) == 0) NA_real_ else mean(base_vals_eptrich, na.rm = TRUE)
  assign(paste0(s, ".EPTrich.trigger"), data.frame(yintercept = ifelse(is.na(base_mean_eptrich), NA_real_, base_mean_eptrich * 0.85), Lines = "Trigger Level"))

  # EPTabun
  base_vals_eptabun <- macro_means %>% filter(Site == s, Period == "Baseline") %>% pull(EPTabun)
  base_mean_eptabun <- if (length(base_vals_eptabun) == 0) NA_real_ else mean(base_vals_eptabun, na.rm = TRUE)
  assign(paste0(s, ".EPTabun.trigger"), data.frame(yintercept = ifelse(is.na(base_mean_eptabun), NA_real_, base_mean_eptabun * 0.85), Lines = "Trigger Level"))
}

# --- Helper to summarise replicate data with 95% CI (t-based). If n==1, CI = mean (no error bar) ---
summary_with_CI <- function(data, value_col) {
  data %>%
    group_by(Site, Date, Period) %>%
    summarise(
      n = sum(!is.na(.data[[value_col]])),
      mean = mean(.data[[value_col]], na.rm = TRUE),
      sd = sd(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      se = sd / sqrt(n),
      t_mult = ifelse(n > 1, qt(0.975, df = n - 1), NA_real_),
      ci_lower = ifelse(n > 1, mean - t_mult * se, mean),
      ci_upper = ifelse(n > 1, mean + t_mult * se, mean),
      # Clamp values to range 0–100
      ci_lower = pmax(ci_lower, 0),
      ci_upper = pmin(ci_upper, 100)
    )
}


# --- Summarise replicate-level data for plotting ---
macro_qmci_summary    <- summary_with_CI(macro, "QMCI")
macro_eptrich_summary <- summary_with_CI(macro, "EPTrich")
macro_eptabun_summary <- summary_with_CI(macro, "EPTabun")

# --- Generic plotting function (plots mean with 95% CI + trigger line) ---
plot_macro_metric <- function(summary_data, trigger_df, y_label, theme_style, palette_scale) {
  ggplot(summary_data, aes(x = Date, y = mean, colour = Period)) +
    theme_style +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), width = 16 * 24 * 60 * 60, na.rm = TRUE) +
    geom_point(size = 2) +
    geom_hline(aes(yintercept = yintercept, color = Lines), data = trigger_df, linewidth = 0.8, na.rm = TRUE) +
    labs(y = y_label, x = "") +
    palette_scale + coord_cartesian(clip = "off")
}

# --- Build per-site plots (keeps earlier site set: EM1,EM2,EM3,EM4,EM7,EM8) ---
sites_plot_order <- c("EM1", "EM2", "EM3", "EM4", "EM7", "EM8")

for (s in sites_plot_order) {
  # choose palette mapping consistent with your original code (EM3 used generaltrigger)
  pal_choice <- if (s == "EM3") palette.generaltrigger else palette.generaltrigger.noincident

  # QMCI
  qmci_plot_data <- macro_qmci_summary %>% filter(Site == s)
  qmci_trigger_df <- get(paste0(s, ".qmci.trigger"))
  assign(paste0(s, ".qmciplot"),
         plot_macro_metric(qmci_plot_data, qmci_trigger_df, "QMCI", Theme_QMCI, pal_choice))

  # EPTrich
  eptrich_plot_data <- macro_eptrich_summary %>% filter(Site == s)
  eptrich_trigger_df <- get(paste0(s, ".EPTrich.trigger"))
  assign(paste0(s, ".EPTrichplot"),
         plot_macro_metric(eptrich_plot_data, eptrich_trigger_df, "%EPT Richness", Theme_EPTrich, pal_choice))

  # EPTabun
  eptabun_plot_data <- macro_eptabun_summary %>% filter(Site == s)
  eptabun_trigger_df <- get(paste0(s, ".EPTabun.trigger"))
  assign(paste0(s, ".EPTabunplot"),
         plot_macro_metric(eptabun_plot_data, eptabun_trigger_df, "%EPT Abundance", Theme_EPTabun, pal_choice))
}

# --- Arrange pages exactly like your original pipeline and save PDF + JPGs ---
macropage1 <- ggarrange(EM1.qmciplot, EM1.EPTrichplot, EM1.EPTabunplot,
                       labels = c("a)", "b)", "c)"), font.label = list(size = 12),
                       ncol = 1, nrow = 3, hjust = 0.5, common.legend = TRUE) + theme(plot.margin = margin(1,2,1,2, "cm"))
m1plot <- annotate_figure(macropage1, top = text_grob("EM1", face = "bold", size = 14, vjust = 1.5))

macropage2 <- ggarrange(EM2.qmciplot, EM2.EPTrichplot, EM2.EPTabunplot,
                       labels = c("a)", "b)", "c)"), font.label = list(size = 12),
                       ncol = 1, nrow = 3, hjust = 0.5, common.legend = TRUE) + theme(plot.margin = margin(1,2,1,2, "cm"))
m2plot <- annotate_figure(macropage2, top = text_grob("EM2", face = "bold", size = 14, vjust = 1.5))

macropage3 <- ggarrange(EM3.qmciplot, EM3.EPTrichplot, EM3.EPTabunplot,
                       labels = c("a)", "b)", "c)"), font.label = list(size = 12),
                       ncol = 1, nrow = 3, hjust = 0.5, common.legend = TRUE) + theme(plot.margin = margin(1,2,1,2, "cm"))
m3plot <- annotate_figure(macropage3, top = text_grob("EM3", face = "bold", size = 14, vjust = 1.5))

macropage4 <- ggarrange(EM4.qmciplot, EM4.EPTrichplot, EM4.EPTabunplot,
                       labels = c("a)", "b)", "c)"), font.label = list(size = 12),
                       ncol = 1, nrow = 3, hjust = 0.5, common.legend = TRUE) + theme(plot.margin = margin(1,2,1,2, "cm"))
m4plot <- annotate_figure(macropage4, top = text_grob("EM4", face = "bold", size = 14, vjust = 1.5))

macropage5 <- ggarrange(EM7.qmciplot, EM7.EPTrichplot, EM7.EPTabunplot,
                       labels = c("a)", "b)", "c)"), font.label = list(size = 12),
                       ncol = 1, nrow = 3, hjust = 0.5, common.legend = TRUE) + theme(plot.margin = margin(1,2,1,2, "cm"))
m5plot <- annotate_figure(macropage5, top = text_grob("EM7", face = "bold", size = 14, vjust = 1.5))

macropage6 <- ggarrange(EM8.qmciplot, EM8.EPTrichplot, EM8.EPTabunplot,
                       labels = c("a)", "b)", "c)"), font.label = list(size = 12),
                       ncol = 1, nrow = 3, hjust = 0.5, common.legend = TRUE) + theme(plot.margin = margin(1,2,1,2, "cm"))
m6plot <- annotate_figure(macropage6, top = text_grob("EM8", face = "bold", size = 14, vjust = 1.5))

mplot_list <- list(m1plot, m2plot, m3plot, m4plot, m5plot, m6plot)

# Save combined PDF (A4)
pdf("mm_plots.pdf", width = 8.27, height = 11.69)  # A4 in inches
for (i in seq_along(mplot_list)) {
  print(mplot_list[[i]])
  if (i < length(mplot_list)) cat("\f")
}
dev.off()

# Save individual JPGs
mplot_named_list <- list(
  EM1 = m1plot, EM2 = m2plot, EM3 = m3plot,
  EM4 = m4plot, EM7 = m5plot, EM8 = m6plot
)

for (name in names(mplot_named_list)) {
  ggsave(
    filename = paste0(name, "DRAFT.jpg"),
    plot = mplot_named_list[[name]],
    width = 9, height = 12, units = "in", dpi = 300
  )
  
  
  # --- Save individual metric plots as JPEGs ---
  # Create output folder if not exists
  jpeg_dir <- "metric_plots_jpeg"
  if (!dir.exists(jpeg_dir)) dir.create(jpeg_dir)
  
  # Loop over each site and metric
  for (s in sites_plot_order) {
    # Get each metric plot by constructed name
    qmci_plot      <- get(paste0(s, ".qmciplot"))
    eptrich_plot   <- get(paste0(s, ".EPTrichplot"))
    eptabun_plot   <- get(paste0(s, ".EPTabunplot"))
    
    # Save each one separately
    ggsave(
      filename = file.path(jpeg_dir, paste0(s, "_QMCI_DRAFT.jpg")),
      plot = qmci_plot,
      width = 9, height = 6, units = "in", dpi = 300
    )
    
    ggsave(
      filename = file.path(jpeg_dir, paste0(s, "_EPTrich_DRAFT.jpg")),
      plot = eptrich_plot,
      width = 9, height = 6, units = "in", dpi = 300
    )
    
    ggsave(
      filename = file.path(jpeg_dir, paste0(s, "_EPTabun_DRAFT.jpg")),
      plot = eptabun_plot,
      width = 9, height = 6, units = "in", dpi = 300
    )
  }
}

