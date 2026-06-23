# errors.R — validation error type and per-domain result object.

ValidationError <- function(domain, severity, file, sheet, location, message) {
  stopifnot(severity %in% c("error", "warning"))
  structure(
    list(domain = domain, severity = severity, file = file,
         sheet = sheet, location = location, message = message),
    class = "ValidationError"
  )
}

format.ValidationError <- function(x, ...) {
  sprintf("[%s] %s → %s → %s: %s",
          toupper(x$severity), x$file, x$sheet, x$location, x$message)
}

print.ValidationError <- function(x, ...) {
  cat(format(x), "\n")
  invisible(x)
}

DomainResult <- R6::R6Class(
  "DomainResult",
  public = list(
    data = NULL,
    errors = NULL,
    initialize = function(data = NULL, errors = list()) {
      self$data <- data
      self$errors <- errors
    },
    add_error = function(e) {
      self$errors <- c(self$errors, list(e))
      invisible(self)
    },
    ok = function() {
      !any(vapply(self$errors,
                  function(e) identical(e$severity, "error"),
                  logical(1)))
    }
  )
)
