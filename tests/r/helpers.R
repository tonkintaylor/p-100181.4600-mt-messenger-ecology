# Helper for testthat to set working directory
# Ensure working directory is project root
if (!file.exists("src/r/data/schemas.R")) {
  # Find project root by looking for .git directory
  wd <- getwd()
  while (!file.exists(file.path(wd, ".git"))) {
    new_wd <- dirname(wd)
    if (new_wd == wd) break  # Stop at filesystem root
    wd <- new_wd
  }
  if (file.exists(file.path(wd, "src/r/data/schemas.R"))) {
    setwd(wd)
  }
}
