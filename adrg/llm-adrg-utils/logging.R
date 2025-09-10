#' @title LLM Logging Utilities
#' @description Functions for logging LLM API calls to files
#' @keywords internal

# Create logs directory if it doesn't exist
ensure_logs_dir <- function() {
  logs_dir <- here::here("logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE)
  }
  logs_dir
}

#' Log LLM call details to a daily log file
#'
#' @param prompt The prompt sent to the LLM
#' @param model The model used for the call
#' @param response The response received from the LLM
#' @export
log_llm_call <- function(prompt, model, response) {
  logs_dir <- ensure_logs_dir()
  date <- format(Sys.time(), "%Y%m%d")
  log_file <- file.path(logs_dir, sprintf("llm_calls_%s.log", date))
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  is_new_file <- !file.exists(log_file)

  # Only create the file if it doesn't exist
  if (is_new_file) file.create(log_file)

  # Add a run header if this is the first log today
  if (is_new_file) {
    run_header <- sprintf(
      "%s\n=== NEW RUN STARTED ===\nTimestamp: %s\n%s\n",
      paste(rep("=", 80), collapse = ""),
      timestamp,
      paste(rep("=", 80), collapse = "")
    )
    write(run_header, log_file)
    cat(sprintf("Starting new llm log file at %s\n", log_file))
  }

  # Add the LLM call log entry
  log_entry <- sprintf(
    "\n=== LLM Call Log === [%s] Model: %s\nPrompt:\n%s\n\nResponse:\n%s\n%s\n",
    timestamp,
    model,
    prompt,
    response,
    paste(rep("=", 80), collapse = "")
  )

  write(log_entry, log_file, append = TRUE)
}
