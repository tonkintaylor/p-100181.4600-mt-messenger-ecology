# Setup for testthat - ensure working directory is project root
if (!file.exists("src/r/data")) {
  # If we're not in the project root, try to find it
  potential_root <- dirname(dirname(getwd()))
  if (file.exists(file.path(potential_root, "src/r/data"))) {
    setwd(potential_root)
  }
}
