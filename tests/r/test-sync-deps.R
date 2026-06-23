# Tests for the pure helpers in scripts/sync_r_packages.R.
# Sourcing the script only defines functions (main is guarded by sys.nframe).
source(file.path(ROOT, "scripts", "sync_r_packages.R"))

test_that("read_project_meta parses Imports, snapshot date and R version", {
  desc <- withr::local_tempfile()
  writeLines(c(
    "Type: project",
    "Title: Example",
    "Imports:",
    "    readxl,",
    "    dplyr (>= 1.0.0),",
    "    R",
    "Config/R/Version: 4.5",
    "Config/Repo/Snapshot: 2026-06-01"
  ), desc)

  meta <- read_project_meta(desc)

  # "R" is dropped; version constraints are stripped.
  expect_setequal(meta$packages, c("readxl", "dplyr"))
  expect_identical(meta$snapshot, "2026-06-01")
  expect_identical(meta$r_version, "4.5")
})

test_that("the real DESCRIPTION carries a snapshot date and the used packages", {
  meta <- read_project_meta(file.path(ROOT, "DESCRIPTION"))
  expect_match(meta$snapshot, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  # Packages the source actually uses must be declared.
  expect_true(all(c("tibble", "withr", "openxlsx", "RcppTOML") %in% meta$packages))
})

test_that("ppm_repo_url builds platform-appropriate URLs", {
  # Windows/macOS get the plain dated URL (serves binaries there).
  expect_identical(
    ppm_repo_url("2026-06-01", sysname = "Windows"),
    "https://packagemanager.posit.co/cran/2026-06-01"
  )
  expect_identical(
    ppm_repo_url("2026-06-01", sysname = "Darwin"),
    "https://packagemanager.posit.co/cran/2026-06-01"
  )

  # Linux with a known codename uses the binary path.
  os <- withr::local_tempfile()
  writeLines(c('ID=ubuntu', 'VERSION_CODENAME=noble'), os)
  expect_identical(
    ppm_repo_url("2026-06-01", sysname = "Linux", os_release = os),
    "https://packagemanager.posit.co/cran/__linux__/noble/2026-06-01"
  )

  # Linux without a detectable codename falls back to the source URL.
  expect_identical(
    ppm_repo_url("2026-06-01", sysname = "Linux", os_release = "/no/such/file"),
    "https://packagemanager.posit.co/cran/2026-06-01"
  )
})

test_that("r_version_matches compares only major.minor", {
  expect_true(r_version_matches("4.5", numeric_version("4.5.3")))
  expect_true(r_version_matches("4.5", numeric_version("4.5.0")))
  expect_false(r_version_matches("4.5", numeric_version("4.6.0")))
  expect_true(r_version_matches(NA_character_, numeric_version("4.6.0"))) # no pin -> ok
})
