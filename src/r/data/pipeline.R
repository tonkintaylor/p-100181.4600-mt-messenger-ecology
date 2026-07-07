# pipeline.R — run all domains; enforce no-partial-output; write combined xlsx.

run_pipeline <- function(config) {
  results <- list(
    process_macro_domain(config$macroinvertebrate_db),
    process_macro_species_domain(config$macroinvertebrate_db),
    process_sediment_domain(config$aquatic_monitoring_db),
    process_sediment_size_domain(config$aquatic_monitoring_db),
    process_clarity_domain(config$aquatic_monitoring_db),
    process_rpd_domain(config$aquatic_monitoring_db),
    process_ldv_domain(config$aquatic_monitoring_db),
    process_fish_domain(config$aquatic_monitoring_db),
    process_macro_summary_domain(config$macroinvertebrate_db),
    process_fish_summary_domain(config$aquatic_monitoring_db),
    process_sediment_summary_domain(config$aquatic_monitoring_db),
    process_rpd_summary_domain(config$aquatic_monitoring_db),
    process_macro_sample_domain(config$macroinvertebrate_db),
    process_field_wq_domain(config$aquatic_monitoring_db)
  )
  all_errors <- do.call(c, lapply(results, function(r) r$errors))
  if (is.null(all_errors)) all_errors <- list()

  if (!all(vapply(results, function(r) r$ok(), logical(1)))) {
    return(list(success = FALSE, errors = all_errors))
  }
  combined <- list()
  for (r in results) if (!is.null(r$data)) combined <- c(combined, r$data)
  write_data_xlsx(combined, config$data_xlsx)
  list(success = TRUE, errors = all_errors)
}
