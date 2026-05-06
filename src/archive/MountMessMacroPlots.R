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
macro <- read_xlsx("Data.xlsx", sheet = "Macro")

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

EM1 <- subset(macro, Site=="EM1")
EM2 <- subset(macro, Site=="EM2")
EM3 <- subset(macro, Site=="EM3")
EM4 <- subset(macro, Site=="EM4")
EM7 <- subset(macro, Site=="EM7")
EM8 <- subset(macro, Site=="EM8")

#Add winter box date range where required
#Check palette combinations are suitable

#Match limit to winter box or end of sampling month if in summer.
# Date limits extended into Q4 to cover monitoring for an incident which occurred in Q1.
macrolims <- as.POSIXct(c("1/08/2018","1/05/2025"), format = "%d/%m/%Y")

#Baseline min triggers

### Triggers QMCI
#EM1.qmci.trigger <- data.frame(yintercept = c(4.02), Lines = c("The Baseline\nMinimum"))
#EM2.qmci.trigger <- data.frame(yintercept = c(2.31), Lines = c("The Baseline\nMinimum"))
#EM3.qmci.trigger <- data.frame(yintercept = c(4.37), Lines = c("The Baseline\nMinimum"))
#EM4.qmci.trigger <- data.frame(yintercept = c(4.85), Lines = c("The Baseline\nMinimum"))
#EM7.qmci.trigger <- data.frame(yintercept = c(5.69), Lines = c("The Baseline\nMinimum"))
#EM8.qmci.trigger <- data.frame(yintercept = c(2.51), Lines = c("The Baseline\nMinimum"))

### Triggers EPTrich
#EM1.EPTrich.trigger <- data.frame(yintercept = c(37.2), Lines = c("The Baseline\nMinimum"))
#EM2.EPTrich.trigger <- data.frame(yintercept = c(32.4), Lines = c("The Baseline\nMinimum"))
#EM3.EPTrich.trigger <- data.frame(yintercept = c(33.9), Lines = c("The Baseline\nMinimum"))
#EM4.EPTrich.trigger <- data.frame(yintercept = c(27.6), Lines = c("The Baseline\nMinimum"))
#EM7.EPTrich.trigger <- data.frame(yintercept = c(39.9), Lines = c("The Baseline\nMinimum"))
#EM8.EPTrich.trigger <- data.frame(yintercept = c(33.3), Lines = c("The Baseline\nMinimum"))

### Triggers EPTabun
#EM1.EPTabun.trigger <- data.frame(yintercept = c(14.1), Lines = c("The Baseline\nMinimum"))
#EM2.EPTabun.trigger <- data.frame(yintercept = c(2.8), Lines = c("The Baseline\nMinimum"))
#EM3.EPTabun.trigger <- data.frame(yintercept = c(11.8), Lines = c("The Baseline\nMinimum"))
#EM4.EPTabun.trigger <- data.frame(yintercept = c(25.0), Lines = c("The Baseline\nMinimum"))
#EM7.EPTabun.trigger <- data.frame(yintercept = c(36.2), Lines = c("The Baseline\nMinimum"))
#EM8.EPTabun.trigger <- data.frame(yintercept = c(4.2), Lines = c("The Baseline\nMinimum"))

#15% triggers
EM1.qmci.trigger.value <- mean(macro$QMCI[macro$Site == "EM1" & macro$Period == "Baseline"], na.rm = TRUE) * 0.85
EM1.qmci.trigger <- data.frame(yintercept = EM1.qmci.trigger.value,  Lines = "Trigger Level")
EM2.qmci.trigger.value <- mean(macro$QMCI[macro$Site == "EM2" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM2.qmci.trigger <- data.frame(yintercept = EM2.qmci.trigger.value,  Lines = "Trigger Level")
EM3.qmci.trigger.value <- mean(macro$QMCI[macro$Site == "EM3" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM3.qmci.trigger <- data.frame(yintercept = EM3.qmci.trigger.value,  Lines = "Trigger Level")
EM4.qmci.trigger.value <- mean(macro$QMCI[macro$Site == "EM4" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM4.qmci.trigger <- data.frame(yintercept = EM4.qmci.trigger.value,  Lines = "Trigger Level")
EM7.qmci.trigger.value <- mean(macro$QMCI[macro$Site == "EM7" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM7.qmci.trigger <- data.frame(yintercept = EM7.qmci.trigger.value,  Lines = "Trigger Level")
EM8.qmci.trigger.value <- mean(macro$QMCI[macro$Site == "EM8" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM8.qmci.trigger <- data.frame(yintercept = EM8.qmci.trigger.value,  Lines = "Trigger Level")

EM1.EPTrich.trigger.value <- mean(macro$EPTrich[macro$Site == "EM1" & macro$Period == "Baseline"], na.rm = TRUE) * 0.85
EM1.EPTrich.trigger <- data.frame(yintercept = EM1.EPTrich.trigger.value,  Lines = "Trigger Level")
EM2.EPTrich.trigger.value <- mean(macro$EPTrich[macro$Site == "EM2" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM2.EPTrich.trigger <- data.frame(yintercept = EM2.EPTrich.trigger.value,  Lines = "Trigger Level")
EM3.EPTrich.trigger.value <- mean(macro$EPTrich[macro$Site == "EM3" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM3.EPTrich.trigger <- data.frame(yintercept = EM3.EPTrich.trigger.value,  Lines = "Trigger Level")
EM4.EPTrich.trigger.value <- mean(macro$EPTrich[macro$Site == "EM4" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM4.EPTrich.trigger <- data.frame(yintercept = EM4.EPTrich.trigger.value,  Lines = "Trigger Level")
EM7.EPTrich.trigger.value <- mean(macro$EPTrich[macro$Site == "EM7" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM7.EPTrich.trigger <- data.frame(yintercept = EM7.EPTrich.trigger.value,  Lines = "Trigger Level")
EM8.EPTrich.trigger.value <- mean(macro$EPTrich[macro$Site == "EM8" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM8.EPTrich.trigger <- data.frame(yintercept = EM8.EPTrich.trigger.value,  Lines = "Trigger Level")

EM1.EPTabun.trigger.value <- mean(macro$EPTabun[macro$Site == "EM1" & macro$Period == "Baseline"], na.rm = TRUE) * 0.85
EM1.EPTabun.trigger <- data.frame(yintercept = EM1.EPTabun.trigger.value,  Lines = "Trigger Level")
EM2.EPTabun.trigger.value <- mean(macro$EPTabun[macro$Site == "EM2" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM2.EPTabun.trigger <- data.frame(yintercept = EM2.EPTabun.trigger.value,  Lines = "Trigger Level")
EM3.EPTabun.trigger.value <- mean(macro$EPTabun[macro$Site == "EM3" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM3.EPTabun.trigger <- data.frame(yintercept = EM3.EPTabun.trigger.value,  Lines = "Trigger Level")
EM4.EPTabun.trigger.value <- mean(macro$EPTabun[macro$Site == "EM4" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM4.EPTabun.trigger <- data.frame(yintercept = EM4.EPTabun.trigger.value,  Lines = "Trigger Level")
EM7.EPTabun.trigger.value <- mean(macro$EPTabun[macro$Site == "EM7" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM7.EPTabun.trigger <- data.frame(yintercept = EM7.EPTabun.trigger.value,  Lines = "Trigger Level")
EM8.EPTabun.trigger.value <- mean(macro$EPTabun[macro$Site == "EM8" & macro$Period == "Baseline"], na.rm = TRUE)*0.85
EM8.EPTabun.trigger <- data.frame(yintercept = EM8.EPTabun.trigger.value,  Lines = "Trigger Level")

### MCI plots ###

### theme
# Add line for winter boxes where required
### QMCI plots ###

# theme
# Add line for winter boxes where required

Theme_QMCI <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),plot.title = element_text(size=14,face="bold",hjust = 0.5),legend.text = element_text(size=9), legend.title = element_blank(), axis.text.x = element_text(angle = 90, vjust = -0.5), legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2019-01-01")), xmax = as.POSIXct(c("2019-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2020-01-01")), xmax = as.POSIXct(c("2020-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2021-01-01")), xmax = as.POSIXct(c("2021-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2022-01-01")), xmax = as.POSIXct(c("2022-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2023-01-01")), xmax = as.POSIXct(c("2023-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2024-01-01")), xmax = as.POSIXct(c("2024-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2025-01-01")), xmax = as.POSIXct(c("2025-03-31")), ymin = -Inf, ymax = Inf),
  scale_x_datetime(limits=macrolims, breaks=date_breaks("3 month"), labels=date_format("%b %y")),
  scale_y_continuous(limits = c(0,8)),
  scale_alpha_manual(name = NULL,values = c(1),breaks = c("Baseline \nMonitoring End"),guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept=as.POSIXct(c("2022-02-28")),alpha="Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  geom_point(size = 2),
  ylab("QMCI"), xlab(""))

# plots

EM1.qmciplot <- ggplot(EM1, aes(x=Date, y=QMCI, colour = Period)) + Theme_QMCI + geom_hline(aes(yintercept = yintercept, color = Lines), EM1.qmci.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM2.qmciplot <- ggplot(EM2, aes(x=Date, y=QMCI, colour = Period)) + Theme_QMCI + geom_hline(aes(yintercept = yintercept, color = Lines), EM2.qmci.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM3.qmciplot <- ggplot(EM3, aes(x=Date, y=QMCI, colour = Period)) + Theme_QMCI + geom_hline(aes(yintercept = yintercept, color = Lines), EM3.qmci.trigger, linewidth = 0.8) + palette.generaltrigger
EM4.qmciplot <- ggplot(EM4, aes(x=Date, y=QMCI, colour = Period)) + Theme_QMCI + geom_hline(aes(yintercept = yintercept, color = Lines), EM4.qmci.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM7.qmciplot <- ggplot(EM7, aes(x=Date, y=QMCI, colour = Period)) + Theme_QMCI + geom_hline(aes(yintercept = yintercept, color = Lines), EM7.qmci.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM8.qmciplot <- ggplot(EM8, aes(x=Date, y=QMCI, colour = Period)) + Theme_QMCI + geom_hline(aes(yintercept = yintercept, color = Lines), EM8.qmci.trigger, linewidth = 0.8) + palette.generaltrigger.noincident


### EPT rich plots ###

# theme

Theme_EPTrich <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),plot.title = element_text(size=14,face="bold",hjust = 0.5),legend.text = element_text(size=9), legend.title = element_blank(), axis.text.x = element_text(angle = 90, vjust = -0.5), legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2019-01-01")), xmax = as.POSIXct(c("2019-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2020-01-01")), xmax = as.POSIXct(c("2020-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2021-01-01")), xmax = as.POSIXct(c("2021-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2022-01-01")), xmax = as.POSIXct(c("2022-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2023-01-01")), xmax = as.POSIXct(c("2023-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2024-01-01")), xmax = as.POSIXct(c("2024-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2025-01-01")), xmax = as.POSIXct(c("2025-03-31")), ymin = -Inf, ymax = Inf),
  scale_x_datetime(limits=macrolims, breaks=date_breaks("3 month"), labels=date_format("%b %y")),
  scale_y_continuous(limits = c(0,80)),
  scale_alpha_manual(name = NULL,values = c(1),breaks = c("Baseline \nMonitoring End"),guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept=as.POSIXct(c("2022-02-28")),alpha="Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  geom_point(size = 2),
  ylab("%EPT Richness"), xlab(""))

# plots

EM1.EPTrichplot <- ggplot(EM1, aes(x=Date, y=EPTrich, colour = Period)) + Theme_EPTrich + geom_hline(aes(yintercept = yintercept, color = Lines), EM1.EPTrich.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM2.EPTrichplot <- ggplot(EM2, aes(x=Date, y=EPTrich, colour = Period)) + Theme_EPTrich + geom_hline(aes(yintercept = yintercept, color = Lines), EM2.EPTrich.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM3.EPTrichplot <- ggplot(EM3, aes(x=Date, y=EPTrich, colour = Period)) + Theme_EPTrich + geom_hline(aes(yintercept = yintercept, color = Lines), EM3.EPTrich.trigger, linewidth = 0.8) + palette.generaltrigger
EM4.EPTrichplot <- ggplot(EM4, aes(x=Date, y=EPTrich, colour = Period)) + Theme_EPTrich + geom_hline(aes(yintercept = yintercept, color = Lines), EM4.EPTrich.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM7.EPTrichplot <- ggplot(EM7, aes(x=Date, y=EPTrich, colour = Period)) + Theme_EPTrich + geom_hline(aes(yintercept = yintercept, color = Lines), EM7.EPTrich.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM8.EPTrichplot <- ggplot(EM8, aes(x=Date, y=EPTrich, colour = Period)) + Theme_EPTrich + geom_hline(aes(yintercept = yintercept, color = Lines), EM8.EPTrich.trigger, linewidth = 0.8) + palette.generaltrigger.noincident

### EPT abun plots ###

# theme

Theme_EPTabun <- list(
  theme_light(),
  theme(plot.margin = margin(5.5,5.5,5.5,5.5),plot.title = element_text(size=14,face="bold",hjust = 0.5),legend.text = element_text(size=9), legend.title = element_blank(), axis.text.x = element_text(angle = 90, vjust = -0.5), legend.position="right"),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2019-01-01")), xmax = as.POSIXct(c("2019-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2020-01-01")), xmax = as.POSIXct(c("2020-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2021-01-01")), xmax = as.POSIXct(c("2021-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2022-01-01")), xmax = as.POSIXct(c("2022-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2023-01-01")), xmax = as.POSIXct(c("2023-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2024-01-01")), xmax = as.POSIXct(c("2024-03-31")), ymin = -Inf, ymax = Inf),
  annotate("rect", fill = "gray80", alpha = 0.4, xmin = as.POSIXct(c("2025-01-01")), xmax = as.POSIXct(c("2025-03-31")), ymin = -Inf, ymax = Inf),
  scale_x_datetime(limits=macrolims, breaks=date_breaks("3 month"), labels=date_format("%b %y")),
  scale_y_continuous(limits = c(0,80)),
  scale_alpha_manual(name = NULL,values = c(1),breaks = c("Baseline \nMonitoring End"),guide = guide_legend(label.hjust = 0, label.theme = element_text(size=9), label.position = "right",override.aes = list(linetype = c(2),color = "black"))),
  geom_vline(aes(xintercept=as.POSIXct(c("2022-02-28")),alpha="Baseline \nMonitoring End"), linetype = 2, linewidth = 0.8),
  geom_point(size = 2),
  ylab("%EPT Abundance"), xlab(""))

# plots

EM1.EPTabunplot <- ggplot(EM1, aes(x=Date, y=EPTabun, colour = Period)) + Theme_EPTabun + geom_hline(aes(yintercept = yintercept, color = Lines), EM1.EPTabun.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM2.EPTabunplot <- ggplot(EM2, aes(x=Date, y=EPTabun, colour = Period)) + Theme_EPTabun + geom_hline(aes(yintercept = yintercept, color = Lines), EM2.EPTabun.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM3.EPTabunplot <- ggplot(EM3, aes(x=Date, y=EPTabun, colour = Period)) + Theme_EPTabun + geom_hline(aes(yintercept = yintercept, color = Lines), EM3.EPTabun.trigger, linewidth = 0.8) + palette.generaltrigger
EM4.EPTabunplot <- ggplot(EM4, aes(x=Date, y=EPTabun, colour = Period)) + Theme_EPTabun + geom_hline(aes(yintercept = yintercept, color = Lines), EM4.EPTabun.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM7.EPTabunplot <- ggplot(EM7, aes(x=Date, y=EPTabun, colour = Period)) + Theme_EPTabun + geom_hline(aes(yintercept = yintercept, color = Lines), EM7.EPTabun.trigger, linewidth = 0.8) + palette.generaltrigger.noincident
EM8.EPTabunplot <- ggplot(EM8, aes(x=Date, y=EPTabun, colour = Period)) + Theme_EPTabun + geom_hline(aes(yintercept = yintercept, color = Lines), EM8.EPTabun.trigger, linewidth = 0.8) + palette.generaltrigger.noincident


# Run ggarrange and annotate pairs, then export pdf. Combine pdfs in pdf viewer.

## Can use ggarrange(labels = c("a)","b)","c)"), font.label = list(size = 9)) # EASY TO CREATE A COMMON LEGEND common.legend = TRUE
macropage1 <- ggarrange(EM1.qmciplot,EM1.EPTrichplot,EM1.EPTabunplot,labels = c("a)","b)","c)"), font.label = list(size = 12), ncol=1,nrow=3,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(1,2,1,2, "cm"))
m1plot <- annotate_figure(macropage1,top = text_grob("EM1", face = "bold", size = 14, vjust = 1.5))
macropage2 <- ggarrange(EM2.qmciplot,EM2.EPTrichplot,EM2.EPTabunplot,labels = c("a)","b)","c)"), font.label = list(size = 12), ncol=1,nrow=3,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(1,2,1,2, "cm"))
m2plot <- annotate_figure(macropage2,top = text_grob("EM2", face = "bold", size = 14, vjust = 1.5))
macropage3 <- ggarrange(EM3.qmciplot,EM3.EPTrichplot,EM3.EPTabunplot,labels = c("a)","b)","c)"), font.label = list(size = 12), ncol=1,nrow=3,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(1,2,1,2, "cm"))
m3plot <- annotate_figure(macropage3,top = text_grob("EM3", face = "bold", size = 14, vjust = 1.5))
macropage4 <- ggarrange(EM4.qmciplot,EM4.EPTrichplot,EM4.EPTabunplot,labels = c("a)","b)","c)"), font.label = list(size = 12), ncol=1,nrow=3,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(1,2,1,2, "cm"))
m4plot <- annotate_figure(macropage4,top = text_grob("EM4", face = "bold", size = 14, vjust = 1.5))
macropage5 <- ggarrange(EM7.qmciplot,EM7.EPTrichplot,EM7.EPTabunplot,labels = c("a)","b)","c)"), font.label = list(size = 12), ncol=1,nrow=3,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(1,2,1,2, "cm"))
m5plot <- annotate_figure(macropage5,top = text_grob("EM7", face = "bold", size = 14, vjust = 1.5))
macropage6 <- ggarrange(EM8.qmciplot,EM8.EPTrichplot,EM8.EPTabunplot,labels = c("a)","b)","c)"), font.label = list(size = 12), ncol=1,nrow=3,hjust = 0.5,common.legend = T)+theme(plot.margin = margin(1,2,1,2, "cm"))
m6plot <- annotate_figure(macropage6,top = text_grob("EM8", face = "bold", size = 14, vjust = 1.5))

mplot_list <- list(m1plot, m2plot, m3plot, m4plot, m5plot, m6plot) # Add more plots to the list

# Create a PDF file
pdf("mm_plots.pdf", width = 8.27, height = 11.69)  # A4 size in inches

# Loop through each plot and arrange on a separate page
for (i in seq_along(mplot_list)) {
  mplot <- mplot_list[[i]]
  
  print(mplot)
  
  if (i < length(mplot_list)) {
    cat("\f")  # Page break between plots
  }
}

# Close the PDF file
dev.off()





# Save individual
mplot_list <- list(
  EM1 = m1plot,
  EM2 = m2plot,
  EM3 = m3plot,
  EM4 = m4plot,
  EM7 = m5plot,
  EM8 = m6plot
)

for (name in names(mplot_list)) {
  ggsave(
    filename = paste0(name, ".jpg"),
    plot = mplot_list[[name]],
    width = 9, height = 12, units = "in", dpi = 300
  )
}






