# test-entrypoints.R — entry-point smoke tests via system2 (exit-code assertions).
# Mirrors tests/test_cli.py cases for run_data.R and run_pipeline.R.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Write a minimal valid cycle.toml with dummy (but existing) input files.
write_valid_toml <- function(dir) {
  macro   <- file.path(dir, "macro.xlsx");   file.create(macro)
  aquatic <- file.path(dir, "aquatic.xlsx"); file.create(aquatic)
  out     <- file.path(dir, "MtMessengerEcologyData.xlsx")
  toml    <- file.path(dir, "cycle.toml")
  # Escape backslashes for TOML on Windows
  esc <- function(p) gsub("\\\\", "\\\\\\\\", p)
  writeLines(c(
    "[input]",
    sprintf('macroinvertebrate_db = "%s"', esc(macro)),
    sprintf('aquatic_monitoring_db = "%s"', esc(aquatic)),
    "[output]",
    sprintf('data_xlsx = "%s"', esc(out))
  ), toml)
  toml
}

run_data <- function(...) {
  withr::with_dir(ROOT,
    system2("Rscript", c("--vanilla", file.path(ROOT, "src", "r", "run_data.R"), ...),
            stdout = TRUE, stderr = TRUE))
}

run_data_rc <- function(...) {
  attr(
    withr::with_dir(ROOT,
      suppressWarnings(
        system2("Rscript", c("--vanilla", file.path(ROOT, "src", "r", "run_data.R"), ...),
                stdout = TRUE, stderr = TRUE)
      )),
    "status"
  ) %||% 0L
}

run_pipeline_rc <- function(...) {
  attr(
    withr::with_dir(ROOT,
      suppressWarnings(
        system2("Rscript", c("--vanilla", file.path(ROOT, "src", "r", "run_pipeline.R"), ...),
                stdout = TRUE, stderr = TRUE)
      )),
    "status"
  ) %||% 0L
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# run_data.R — config error: missing toml
# ---------------------------------------------------------------------------

test_that("run_data.R exits 1 when config file is missing", {
  rc <- run_data_rc((file.path(tempdir(), "nonexistent_12345.toml")))
  expect_equal(rc, 1L)
})

# ---------------------------------------------------------------------------
# run_data.R — config error: missing input files
# ---------------------------------------------------------------------------

test_that("run_data.R exits 1 when input files in toml are missing", {
  d <- withr::local_tempdir()
  toml <- file.path(d, "cycle.toml")
  # Write toml pointing at non-existent files
  writeLines(c(
    "[input]",
    'macroinvertebrate_db = "nope_macro.xlsx"',
    'aquatic_monitoring_db = "nope_aquatic.xlsx"',
    "[output]",
    sprintf('data_xlsx = "%s"', gsub("\\\\", "\\\\\\\\", file.path(d, "out.xlsx")))
  ), toml)
  rc <- run_data_rc((toml))
  expect_equal(rc, 1L)
})

# ---------------------------------------------------------------------------
# run_data.R --validate — config error exits 1
# ---------------------------------------------------------------------------

test_that("run_data.R --validate exits 1 when config is missing", {
  rc <- run_data_rc((file.path(tempdir(), "nonexistent_99999.toml")), "--validate")
  expect_equal(rc, 1L)
})

# ---------------------------------------------------------------------------
# run_data.R — valid config with empty xlsx files exits 1 (pipeline data error)
# ---------------------------------------------------------------------------

test_that("run_data.R exits 1 on valid config but empty input xlsx (pipeline fails)", {
  d <- withr::local_tempdir()
  toml <- write_valid_toml(d)
  rc <- run_data_rc((toml))
  expect_equal(rc, 1L)
})

# ---------------------------------------------------------------------------
# run_data.R --validate — valid config with empty xlsx files exits 1 (domain errors)
# ---------------------------------------------------------------------------

test_that("run_data.R --validate exits 1 on empty input xlsx (validation fails)", {
  d <- withr::local_tempdir()
  toml <- write_valid_toml(d)
  rc <- run_data_rc((toml), "--validate")
  expect_equal(rc, 1L)
})

# ---------------------------------------------------------------------------
# run_data.R --validate — live DBs from cycle.toml (success path)
# ---------------------------------------------------------------------------

test_that("run_data.R --validate exits 0 with real DBs from cycle.toml", {
  cfg <- tryCatch(
    local({
      source(file.path(ROOT, "src", "r", "data", "config.R"))
      load_config(file.path(ROOT, "cycle.toml"))
    }),
    error = function(e) NULL
  )
  skip_if(is.null(cfg), "cycle.toml not available")
  skip_if(!file.exists(cfg$macroinvertebrate_db),
    paste("macroinvertebrate_db not reachable:", cfg$macroinvertebrate_db))
  skip_if(!file.exists(cfg$aquatic_monitoring_db),
    paste("aquatic_monitoring_db not reachable:", cfg$aquatic_monitoring_db))

  rc <- run_data_rc((file.path(ROOT, "cycle.toml")), "--validate")
  expect_equal(rc, 0L)
})

# ---------------------------------------------------------------------------
# run_pipeline.R — config error: missing toml exits non-zero
# ---------------------------------------------------------------------------

test_that("run_pipeline.R exits non-zero when config file is missing", {
  rc <- run_pipeline_rc((file.path(tempdir(), "nonexistent_pipeline.toml")))
  expect_true(rc != 0L)
})

# ---------------------------------------------------------------------------
# run_pipeline.R — valid config with empty xlsx: data step fails, propagates exit 1
# ---------------------------------------------------------------------------

test_that("run_pipeline.R exits 1 when data step fails (empty xlsx)", {
  d <- withr::local_tempdir()
  toml <- write_valid_toml(d)
  rc <- run_pipeline_rc((toml))
  expect_equal(rc, 1L)
})
