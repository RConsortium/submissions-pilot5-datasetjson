#************************************************************************
# Purpose:     Run all ADaMs and TLF programs
# Input:       5 ADaM programs and 4 TLF Programs
# Output:      5 ADaM rds files; TLFs: 1 pdf, 1 out, 2 rtf
#************************************************************************

library(purrr)
library(stringr)

source(str_c(
  path$programs, "/", "pilot5-helper-fcns.r"
  ))

# Run all adam scripts
adam_files <- str_c(
  path$programs, "/", c("adsl.r", "adae.r", "adlbc.r", "adtte.r", "adadas.r")
)

walk(adam_files, function(file) {
  tryCatch(
    source(file),
    error = function(e) {
      message(sprintf("Error in %s: %s", file, e$message))
    }
  )
})

tlf_files <- str_c(
  path$programs, "/", c(
    "tlf-demographic.r", "tlf-efficacy.r", "tlf-kmplot.r",
    "tlf-primary.r"
  )
)

walk(tlf_files, function(file) {
  tryCatch(
    source(file),
    error = function(e) {
      message(sprintf("Error in %s: %s", file, e$message))
    }
  )
})
