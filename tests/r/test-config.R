src_data("config.R")

write_toml <- function(dir, macro, aquatic, data_xlsx, extra = "") {
  path <- file.path(dir, "cycle.toml")
  # Escape backslashes in Windows paths for TOML
  macro <- gsub("\\\\", "\\\\\\\\", macro)
  aquatic <- gsub("\\\\", "\\\\\\\\", aquatic)
  data_xlsx <- gsub("\\\\", "\\\\\\\\", data_xlsx)
  writeLines(c(
    "[input]",
    sprintf('macroinvertebrate_db = "%s"', macro),
    sprintf('aquatic_monitoring_db = "%s"', aquatic),
    "[output]",
    sprintf('data_xlsx = "%s"', data_xlsx),
    extra
  ), path)
  path
}

test_that("load_config errors when the file is missing", {
  expect_error(load_config(tempfile()), class = "config_error")
})

test_that("load_config defaults figures_dir and tables_dir", {
  d <- withr::local_tempdir()
  macro <- file.path(d, "macro.xlsx"); file.create(macro)
  aquatic <- file.path(d, "aq.xlsx"); file.create(aquatic)
  out <- file.path(d, "out", "Data.xlsx")
  cfg <- load_config(write_toml(d, macro, aquatic, out))
  expect_equal(cfg$figures_dir, file.path(dirname(out), "Figures"))
  expect_equal(cfg$tables_dir, file.path(cfg$figures_dir, "Tables"))
})

test_that("load_config errors on missing input file", {
  d <- withr::local_tempdir()
  out <- file.path(d, "Data.xlsx")
  expect_error(
    load_config(write_toml(d, file.path(d, "nope.xlsx"),
                           file.path(d, "nope2.xlsx"), out)),
    class = "config_error")
})
