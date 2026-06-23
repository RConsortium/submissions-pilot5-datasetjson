#' Run all pilot5 R programs and capture output for R version testing
#'
#' Usage: Rscript run-programs.R [r_version]
#'
#' Writes to run-logs/:
#'   full-output.log  - combined stdout/stderr (via shell 2>&1 | tee)
#'   summary.md       - per-program markdown table for this R version
#'   status.txt       - "success" or "failure"

# Always set a CRAN mirror so install.packages() works without user interaction
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Activate renv library so packages restored by setup-renv are available
# (CI=true in GitHub Actions prevents .Rprofile from doing this automatically)
if (file.exists("renv/activate.R")) source("renv/activate.R")

# The `path` list (sdtm, adam, output, adam_json, programs) is defined in
# .Rprofile which Rscript sources automatically when run from the repo root.
# Provide a clear error if it is somehow missing.
if (!exists("path") || !is.list(path)) {
  stop(
    "The `path` list is not defined. ",
    "Run this script from the repository root so that .Rprofile is sourced."
  )
}

args <- commandArgs(trailingOnly = TRUE)
r_version <- if (length(args) > 0) args[1] else paste(R.version$major, R.version$minor, sep = ".")

SEP <- strrep("=", 70)

cat(sprintf("%s\n", SEP))
cat(sprintf("R VERSION COMPATIBILITY TEST\n"))
cat(sprintf("Testing version : %s\n", r_version))
cat(sprintf("Actual R version: %s\n", R.version.string))
cat(sprintf("Platform        : %s\n", R.version$platform))
cat(sprintf("Started         : %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")))
cat(sprintf("%s\n\n", SEP))

# Create output directories
dir.create("run-logs", showWarnings = FALSE, recursive = TRUE)
dir.create(path$output, showWarnings = FALSE, recursive = TRUE)
dir.create(path$adam_json, showWarnings = FALSE, recursive = TRUE)

# Programs to run in order (ADaMs first, then TLFs)
program_names <- c(
  "adsl.r",
  "adae.r",
  "adlbc.r",
  "adtte.r",
  "adadas.r",
  "tlf-demographic.r",
  "tlf-efficacy.r",
  "tlf-kmplot.r",
  "tlf-primary.r"
)
program_paths <- file.path(path$programs, program_names)

#' Run a single R program and capture messages, warnings, and errors
run_program <- function(prog_name, prog_path) {
  cat(sprintf("\n%s\n", SEP))
  cat(sprintf("PROGRAM : %s\n", prog_name))
  cat(sprintf("STARTED : %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("%s\n", SEP))

  n_messages <- 0L
  n_warnings <- 0L
  n_errors   <- 0L

  if (!file.exists(prog_path)) {
    cat(sprintf("[ERROR] File not found: %s\n", prog_path))
    n_errors <- n_errors + 1L
  } else {
    tryCatch(
      withCallingHandlers(
        source(prog_path, echo = FALSE, local = FALSE),
        message = function(m) {
          n_messages <<- n_messages + 1L
          # conditionMessage(m) already ends with "\n" for message() calls
          cat(sprintf("[MESSAGE] %s", conditionMessage(m)))
          invokeRestart("muffleMessage")
        },
        warning = function(w) {
          n_warnings <<- n_warnings + 1L
          cat(sprintf("[WARNING] %s\n", conditionMessage(w)))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        n_errors <<- n_errors + 1L
        cat(sprintf("[ERROR] %s\n", conditionMessage(e)))
      }
    )
  }

  status <- if (n_errors == 0L) "SUCCESS" else "FAILURE"
  cat(sprintf("\nFINISHED: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("STATUS  : %s  (messages: %d | warnings: %d | errors: %d)\n",
              status, n_messages, n_warnings, n_errors))

  list(
    program    = prog_name,
    success    = n_errors == 0L,
    n_messages = n_messages,
    n_warnings = n_warnings,
    n_errors   = n_errors
  )
}

# Run every program (continue even if one fails)
results <- lapply(
  seq_along(program_names),
  function(i) run_program(program_names[i], program_paths[i])
)

# Overall outcome
all_success <- all(vapply(results, `[[`, logical(1), "success"))

cat(sprintf("\n%s\n", SEP))
cat(sprintf("OVERALL STATUS: %s\n", if (all_success) "SUCCESS" else "FAILURE"))
cat(sprintf("%s\n\n", SEP))

# Write markdown summary
status_emoji <- if (all_success) ":white_check_mark:" else ":x:"

md_lines <- c(
  sprintf("## R %s Results", r_version),
  "",
  sprintf("**Status:** %s %s", status_emoji,
          if (all_success) "All programs ran successfully"
          else "Some programs encountered errors"),
  "",
  "| Program | Status | Messages | Warnings | Errors |",
  "|---------|:------:|:--------:|:--------:|:------:|"
)

for (res in results) {
  icon <- if (res$success) ":white_check_mark:" else ":x:"
  md_lines <- c(md_lines, sprintf(
    "| `%s` | %s | %d | %d | %d |",
    res$program, icon, res$n_messages, res$n_warnings, res$n_errors
  ))
}

writeLines(md_lines, file.path("run-logs", "summary.md"))
writeLines(
  if (all_success) "success" else "failure",
  file.path("run-logs", "status.txt")
)

cat(sprintf("Summary written to: run-logs/summary.md\n"))

# Exit non-zero on any program failure so the workflow step is marked failed
if (!all_success) quit(status = 1L)
