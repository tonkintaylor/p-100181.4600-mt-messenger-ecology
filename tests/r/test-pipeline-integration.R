# test-pipeline-integration.R — full pipeline golden integration gate.
# Runs all 8 domain processors against the real source databases from cycle.toml
# and compares non-Fish output sheets to the golden file via compare_sheet_to_golden.

# Load all modules in dependency order.
src_data("errors.R")
src_data("domain_types.R")
src_data("schemas.R")
src_data("validation.R")
src_data("config.R")
src_data("writer.R")
src_data("domains/clarity.R")
src_data("domains/ldv.R")
src_data("domains/rpd.R")
src_data("domains/sediment_ingest.R")
src_data("domains/sediment.R")
src_data("domains/sediment_size.R")
src_data("domains/macro_ingest.R")
src_data("domains/macro.R")
src_data("domains/macro_species.R")
src_data("domains/macro_summary.R")
src_data("domains/fish.R")
src_data("domains/fish_summary.R")
src_data("pipeline.R")

# helper-golden.R is auto-sourced by test_dir(); for test_file() runs, source it.
if (!exists("compare_sheet_to_golden")) {
  source(file.path(ROOT, "tests", "r", "helper-golden.R"), local = FALSE)
}

test_that("full pipeline matches the golden file on every sheet", {
  # Resolve the real source DBs from cycle.toml; skip if unavailable.
  cfg <- tryCatch(load_config(file.path(ROOT, "cycle.toml")), error = function(e) NULL)
  skip_if(is.null(cfg), "cycle.toml inputs not available in this environment")
  skip_if_not(file.exists(cfg$macroinvertebrate_db),
    paste("macroinvertebrate_db not reachable:", cfg$macroinvertebrate_db))
  skip_if_not(file.exists(cfg$aquatic_monitoring_db),
    paste("aquatic_monitoring_db not reachable:", cfg$aquatic_monitoring_db))

  results <- list(
    process_macro_domain(cfg$macroinvertebrate_db),
    process_macro_species_domain(cfg$macroinvertebrate_db),
    process_sediment_domain(cfg$aquatic_monitoring_db),
    process_sediment_size_domain(cfg$aquatic_monitoring_db),
    process_clarity_domain(cfg$aquatic_monitoring_db),
    process_rpd_domain(cfg$aquatic_monitoring_db),
    process_ldv_domain(cfg$aquatic_monitoring_db),
    process_fish_domain(cfg$aquatic_monitoring_db),
    process_macro_summary_domain(cfg$macroinvertebrate_db),
    process_fish_summary_domain(cfg$aquatic_monitoring_db)
  )
  expect_true(all(vapply(results, function(r) r$ok(), logical(1))),
    info = "All domain processors must succeed (no error-severity errors)")

  combined <- list()
  for (r in results) if (!is.null(r$data)) combined <- c(combined, r$data)

  golden <- golden_path()
  # Fish, MacroSummary and FishSummary are R-only sheets with no golden
  # counterpart; compare them on schema + non-emptiness instead.
  r_only <- c("Fish", "MacroSummary", "FishSummary")
  for (sheet in setdiff(SHEET_ORDER, r_only)) {
    compare_sheet_to_golden(combined[[sheet]], sheet, golden)
  }
  fish <- combined[["Fish"]]
  expect_equal(names(fish), FISH_COLUMNS)
  expect_gt(nrow(fish), 0)

  macro_summary <- combined[["MacroSummary"]]
  expect_equal(names(macro_summary), MACRO_SUMMARY_COLUMNS)
  expect_gt(nrow(macro_summary), 0)

  fish_summary <- combined[["FishSummary"]]
  expect_equal(names(fish_summary), FISH_SUMMARY_COLUMNS)
  expect_gt(nrow(fish_summary), 0)
})
