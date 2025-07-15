#************************************************************************
# Purpose:     Load custom functions into global environment
# Input:       See Helper Functions
# Output:      Side Effects
#************************************************************************

library(purrr)
library(stringr)

# Helpers Files
hepler_fcn_files <- str_c(
  path$programs, "/", c("adam_functions.r", "eff_models.r", "example.r", "fmt.r",
                                                "helpers.r", "Tplyr_helpers.r"))

# Makes all functions available to ADaM and TF programs
walk(hepler_fcn_files, source)


