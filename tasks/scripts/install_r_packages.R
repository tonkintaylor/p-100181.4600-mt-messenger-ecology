required <- c(
  "readxl", "dplyr", "tidyr", "ggplot2", "vegan", "indicspecies",
  "ggrepel", "zoo", "patchwork", "openxlsx", "lubridate"
)
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  cat("  Installing:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org/", quiet = TRUE)
} else {
  cat("  All R packages already installed.\n")
}
