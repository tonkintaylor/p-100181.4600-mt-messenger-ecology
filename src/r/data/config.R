# config.R — load and validate cycle.toml.

config_error <- function(msg) {
  stop(structure(class = c("config_error", "error", "condition"),
                 list(message = msg, call = NULL)))
}

load_config <- function(config_path) {
  if (!file.exists(config_path)) {
    config_error(sprintf("Config file not found: %s", config_path))
  }
  raw <- RcppTOML::parseTOML(config_path)
  input <- raw[["input"]]
  output <- raw[["output"]]
  if (is.null(input)) input <- list()
  if (is.null(output)) output <- list()

  if (is.null(output[["data_xlsx"]])) {
    config_error("Missing required key: [output].data_xlsx")
  }

  # Input DBs are optional: present in build mode, absent in workbook mode.
  macro_db <- if (!is.null(input[["macroinvertebrate_db"]]))
    normalizePath(input[["macroinvertebrate_db"]], mustWork = FALSE) else NULL
  aquatic_db <- if (!is.null(input[["aquatic_monitoring_db"]]))
    normalizePath(input[["aquatic_monitoring_db"]], mustWork = FALSE) else NULL
  data_xlsx <- normalizePath(output[["data_xlsx"]], mustWork = FALSE)

  figures_dir <- output[["figures_dir"]]
  if (is.null(figures_dir)) figures_dir <- file.path(dirname(data_xlsx), "Figures")
  tables_dir <- output[["tables_dir"]]
  if (is.null(tables_dir)) tables_dir <- file.path(figures_dir, "Tables")

  # Only existence-check DBs that were actually provided.
  for (path in Filter(Negate(is.null), list(macro_db, aquatic_db))) {
    if (!file.exists(path)) {
      config_error(sprintf("Input file not found: %s", path))
    }
  }

  list(
    macroinvertebrate_db = macro_db,
    aquatic_monitoring_db = aquatic_db,
    data_xlsx = data_xlsx,
    figures_dir = figures_dir,
    tables_dir = tables_dir
  )
}
