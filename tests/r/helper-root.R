# helper-root.R — locate project root and provide module/asset path helpers.
# Sourced automatically by testthat::test_dir(); pre-sourced for test_file() runs.
local({
  wd <- getwd()
  while (!dir.exists(file.path(wd, ".git")) && dirname(wd) != wd) wd <- dirname(wd)
  assign("ROOT", wd, envir = .GlobalEnv)
})

src_data <- function(file) source(file.path(ROOT, "src", "r", "data", file))
golden_path <- function() file.path(ROOT, "tests", "r", "assets", "expected_Data.xlsx")
