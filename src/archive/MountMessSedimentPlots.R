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
sediment <- read_xlsx("Data.xlsx", sheet = "Sediment")

#### Sediment VA analysis ###

Date<-as.POSIXct(sediment$Date, format="%d/%m/%Y")
sediment$Date=Date

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

#### Sed analysis ###

Date<-as.POSIXct(sediment$Date, format="%d/%m/%Y")
sediment$Date=Date

EM1 <- subset(sediment, Site=="EM1")
EM2 <- subset(sediment, Site=="EM2")
EM3 <- subset(sediment, Site=="EM3")
EM4 <- subset(sediment, Site=="EM4")
EM7 <- subset(sediment, Site=="EM7")
EM8 <- subset(sediment, Site=="EM8")

#Add winter box date range where required
#Check palette combinations are suitable

#Match limit to winter box or end of sampling month if in summer.
# Date limits extended into Q4 to cover monitoring for an incident which occurred in Q1.
svalims <- as.POSIXct(c("1/08/2018","1/05/2025"), format = "%d/%m/%Y")


### Triggers_SAM1
EM1.sediment.trigger.value <- mean(sediment$SAM1[sediment$Site == "EM1" & sediment$Period == "Baseline"], na.rm = TRUE) * 1.15
EM1.SAM1.trigger <- ifelse(EM1.sediment.trigger.value > 100, 100, EM1.sediment.trigger.value)
EM1.SAM1.trigger <- data.frame(yintercept = EM1.SAM1.trigger,  Lines = "Trigger Level")
EM2.sediment.trigger.value <- mean(sediment$SAM1[sediment$Site == "EM2" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM2.SAM1.trigger <- ifelse(EM2.sediment.trigger.value > 100, 100, EM2.sediment.trigger.value)
EM2.SAM1.trigger <- data.frame(yintercept = EM2.SAM1.trigger,  Lines = "Trigger Level")
EM3.sediment.trigger.value <- mean(sediment$SAM1[sediment$Site == "EM3" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM3.SAM1.trigger <- ifelse(EM3.sediment.trigger.value > 100, 100, EM3.sediment.trigger.value)
EM3.SAM1.trigger <- data.frame(yintercept = EM3.SAM1.trigger,  Lines = "Trigger Level")
EM4.sediment.trigger.value <- mean(sediment$SAM1[sediment$Site == "EM4" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM4.SAM1.trigger <- ifelse(EM4.sediment.trigger.value > 100, 100, EM4.sediment.trigger.value)
EM4.SAM1.trigger <- data.frame(yintercept = EM4.SAM1.trigger,  Lines = "Trigger Level")
EM7.sediment.trigger.value <- mean(sediment$SAM1[sediment$Site == "EM7" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM7.SAM1.trigger <- ifelse(EM7.sediment.trigger.value > 100, 100, EM7.sediment.trigger.value)
EM7.SAM1.trigger <- data.frame(yintercept = EM7.SAM1.trigger,  Lines = "Trigger Level")
EM8.sediment.trigger.value <- mean(sediment$SAM1[sediment$Site == "EM8" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM8.SAM1.trigger <- ifelse(EM8.sediment.trigger.value > 100, 100, EM8.sediment.trigger.value)
EM8.SAM1.trigger <- data.frame(yintercept = EM8.SAM1.trigger,  Lines = "Trigger Level")

### Triggers_SAM3
EM1.sediment.trigger.value <- mean(sediment$SAM3[sediment$Site == "EM1" & sediment$Period == "Baseline"], na.rm = TRUE) * 1.15
EM1.SAM3.trigger <- ifelse(EM1.sediment.trigger.value > 100, 100, EM1.sediment.trigger.value)
EM1.SAM3.trigger <- data.frame(yintercept = EM1.SAM3.trigger,  Lines = "Trigger Level")
EM2.sediment.trigger.value <- mean(sediment$SAM3[sediment$Site == "EM2" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM2.SAM3.trigger <- ifelse(EM2.sediment.trigger.value > 100, 100, EM2.sediment.trigger.value)
EM2.SAM3.trigger <- data.frame(yintercept = EM2.SAM3.trigger,  Lines = "Trigger Level")
EM3.sediment.trigger.value <- mean(sediment$SAM3[sediment$Site == "EM3" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM3.SAM3.trigger <- ifelse(EM3.sediment.trigger.value > 100, 100, EM3.sediment.trigger.value)
EM3.SAM3.trigger <- data.frame(yintercept = EM3.SAM3.trigger,  Lines = "Trigger Level")
EM4.sediment.trigger.value <- mean(sediment$SAM3[sediment$Site == "EM4" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM4.SAM3.trigger <- ifelse(EM4.sediment.trigger.value > 100, 100, EM4.sediment.trigger.value)
EM4.SAM3.trigger <- data.frame(yintercept = EM4.SAM3.trigger,  Lines = "Trigger Level")
EM7.sediment.trigger.value <- mean(sediment$SAM3[sediment$Site == "EM7" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM7.SAM3.trigger <- ifelse(EM7.sediment.trigger.value > 100, 100, EM7.sediment.trigger.value)
EM7.SAM3.trigger <- data.frame(yintercept = EM7.SAM3.trigger,  Lines = "Trigger Level")
EM8.sediment.trigger.value <- mean(sediment$SAM3[sediment$Site == "EM8" & sediment$Period == "Baseline"], na.rm = TRUE)*1.15
EM8.SAM3.trigger <- ifelse(EM8.sediment.trigger.value > 100, 100, EM8.sediment.trigger.value)
EM8.SAM3.trigger <- data.frame(yintercept = EM8.SAM3.trigger,  Lines = "Trigger Level")


### sediment plots ###
# Add line for winter boxes when required

Theme_SAM1 <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),plot.title = element_text(size=14,face="bold",hjust = 0.5),legend.text = element_text(size=9), legend.title = element_blank(), axis.text.x = element_text(angle = 90, vjust = -0.5), legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2019-01-01")), xmax = as.POSIXct(c("2019-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2020-01-01")), xmax = as.POSIXct(c("2020-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2021-01-01")), xmax = as.POSIXct(c("2021-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2022-01-01")), xmax = as.POSIXct(c("2022-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2023-01-01")), xmax = as.POSIXct(c("2023-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2024-01-01")), xmax = as.POSIXct(c("2024-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2025-01-01")), xmax = as.POSIXct(c("2025-03-31")), ymin = -Inf, ymax = Inf),
  scale_x_datetime(breaks=date_breaks("3 month"), labels=date_format("%b %y")),
  scale_y_continuous(limits = c(0,102)),
  scale_alpha_manual(name = NULL,values = c(1),breaks = c("Baseline \nMonitoring End"),guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept=as.POSIXct(c("2022-02-28")),alpha="Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  geom_point(size = 2),
  ylab("SAM1 Mean Sediment Cover (%)"), xlab(""))

Theme_SAM3 <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),plot.title = element_text(size=14,face="bold",hjust = 0.5),legend.text = element_text(size=9), legend.title = element_blank(), axis.text.x = element_text(angle = 90, vjust = -0.5), legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2019-01-01")), xmax = as.POSIXct(c("2019-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2020-01-01")), xmax = as.POSIXct(c("2020-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2021-01-01")), xmax = as.POSIXct(c("2021-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2022-01-01")), xmax = as.POSIXct(c("2022-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2023-01-01")), xmax = as.POSIXct(c("2023-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2024-01-01")), xmax = as.POSIXct(c("2024-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2025-01-01")), xmax = as.POSIXct(c("2025-03-31")), ymin = -Inf, ymax = Inf),
  scale_x_datetime(breaks=date_breaks("3 month"), labels=date_format("%b %y")),
  scale_y_continuous(limits = c(0,102)),
  scale_alpha_manual(name = NULL,values = c(1),breaks = c("Baseline \nMonitoring End"),guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept=as.POSIXct(c("2022-02-28")),alpha="Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  geom_point(size = 2),
  ylab("SAM3 Mean Sediment Cover (%)"), xlab(""))


EM1.SAM1plot <- ggplot(EM1, aes(x=Date, y=SAM1, colour = Period)) + Theme_SAM1 + geom_hline(aes(yintercept = yintercept, color = Lines), EM1.SAM1.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM2.SAM1plot <- ggplot(EM2, aes(x=Date, y=SAM1, colour = Period)) + Theme_SAM1 + geom_hline(aes(yintercept = yintercept, color = Lines), EM2.SAM1.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM3.SAM1plot <- ggplot(EM3, aes(x=Date, y=SAM1, colour = Period)) + Theme_SAM1 + geom_hline(aes(yintercept = yintercept, color = Lines), EM3.SAM1.trigger, linewidth = 0.8) + palette.generaltrigger
EM4.SAM1plot <- ggplot(EM4, aes(x=Date, y=SAM1, colour = Period)) + Theme_SAM1 + geom_hline(aes(yintercept = yintercept, color = Lines), EM4.SAM1.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM7.SAM1plot <- ggplot(EM7, aes(x=Date, y=SAM1, colour = Period)) + Theme_SAM1 + geom_hline(aes(yintercept = yintercept, color = Lines), EM7.SAM1.trigger, linewidth = 0.8) + palette.generaltrigger
EM8.SAM1plot <- ggplot(EM8, aes(x=Date, y=SAM1, colour = Period)) + Theme_SAM1 + geom_hline(aes(yintercept = yintercept, color = Lines), EM8.SAM1.trigger, linewidth = 0.8) + palette.generaltrigger.noincident

EM1.SAM3plot <- ggplot(EM1, aes(x=Date, y=SAM3, colour = Period)) + Theme_SAM3 + geom_hline(aes(yintercept = yintercept, color = Lines), EM1.SAM3.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM2.SAM3plot <- ggplot(EM2, aes(x=Date, y=SAM3, colour = Period)) + Theme_SAM3 + geom_hline(aes(yintercept = yintercept, color = Lines), EM2.SAM3.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM3.SAM3plot <- ggplot(EM3, aes(x=Date, y=SAM3, colour = Period)) + Theme_SAM3 + geom_hline(aes(yintercept = yintercept, color = Lines), EM3.SAM3.trigger, linewidth = 0.8) + palette.generaltrigger
EM4.SAM3plot <- ggplot(EM4, aes(x=Date, y=SAM3, colour = Period)) + Theme_SAM3 + geom_hline(aes(yintercept = yintercept, color = Lines), EM4.SAM3.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM7.SAM3plot <- ggplot(EM7, aes(x=Date, y=SAM3, colour = Period)) + Theme_SAM3 + geom_hline(aes(yintercept = yintercept, color = Lines), EM7.SAM3.trigger, linewidth = 0.8) + palette.generaltrigger
EM8.SAM3plot <- ggplot(EM8, aes(x=Date, y=SAM3, colour = Period)) + Theme_SAM3 + geom_hline(aes(yintercept = yintercept, color = Lines), EM8.SAM3.trigger, linewidth = 0.8) + palette.generaltrigger.noincident



### Sediment Plots ###

# Run ggarrange and annotate pairs, then export pdf. Combine pdfs in pdf viewer.

## Can use ggarrange(labels = c("a)","b)","c)"), font.label = list(size = 9)) # EASY TO CREATE A COMMON LEGEND common.legend = TRUE
sedpage1 <- ggarrange(EM1.SAM1plot,EM1.SAM3plot, ncol=1,nrow=2,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(0.6,3,0.6,3, "cm"))
sedplot1 <- annotate_figure(sedpage1,top = text_grob("EM1", face = "bold", size = 14, vjust = 1.5))
sedpage2 <- ggarrange(EM2.SAM1plot,EM2.SAM3plot, ncol=1,nrow=2,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(0.6,3,0.6,3, "cm"))
sedplot2 <- annotate_figure(sedpage2,top = text_grob("EM2", face = "bold", size = 14, vjust = 1.5))
sedpage3 <- ggarrange(EM3.SAM1plot,EM3.SAM3plot, ncol=1,nrow=2,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(0.6,3,0.6,3, "cm"))
sedplot3 <- annotate_figure(sedpage3,top = text_grob("EM3", face = "bold", size = 14, vjust = 1.5))
sedpage4 <- ggarrange(EM4.SAM1plot,EM4.SAM3plot, ncol=1,nrow=2,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(0.6,3,0.6,3, "cm"))
sedplot4 <- annotate_figure(sedpage4,top = text_grob("EM4", face = "bold", size = 14, vjust = 1.5))
sedpage5 <- ggarrange(EM7.SAM1plot,EM7.SAM3plot, ncol=1,nrow=2,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(0.6,3,0.6,3, "cm"))
sedplot5 <- annotate_figure(sedpage5,top = text_grob("EM7", face = "bold", size = 14, vjust = 1.5))
sedpage6 <- ggarrange(EM8.SAM1plot,EM8.SAM3plot, ncol=1,nrow=2,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(0.6,3,0.6,3, "cm"))
sedplot6 <- annotate_figure(sedpage5,top = text_grob("EM8", face = "bold", size = 14, vjust = 1.5))

sedplot_list <- list(sedplot1, sedplot2, sedplot3, sedplot4, sedplot5) # Add more plots to the list

# Create a PDF file
pdf("sedoutput_plots.pdf", width = 8.27, height = 11.69)  # A4 size in inches

# Loop through each plot and arrange on a separate page
for (i in seq_along(sedplot_list)) {
  sedplot <- sedplot_list[[i]]
  
  print(sedplot)
  
  if (i < length(sedplot_list)) {
    cat("\f")  # Page break between plots
  }
}

# Close the PDF file
dev.off()




#Export as JPEGs

# Named list of all individual plots
all_plots <- list(
  EM1.SAM1plot = EM1.SAM1plot,
  EM1.SAM3plot = EM1.SAM3plot,
  EM2.SAM1plot = EM2.SAM1plot,
  EM2.SAM3plot = EM2.SAM3plot,
  EM3.SAM1plot = EM3.SAM1plot,
  EM3.SAM3plot = EM3.SAM3plot,
  EM4.SAM1plot = EM4.SAM1plot,
  EM4.SAM3plot = EM4.SAM3plot,
  EM7.SAM1plot = EM7.SAM1plot,
  EM7.SAM3plot = EM7.SAM3plot,
  EM8.SAM1plot = EM8.SAM1plot,
  EM8.SAM3plot = EM8.SAM3plot
)

# Loop through each and save individually
for (plot_name in names(all_plots)) {
  ggsave(
    filename = paste0(plot_name, ".jpg"),
    plot = all_plots[[plot_name]],
    width = 8, height = 6, units = "in", dpi = 300
  )
}
