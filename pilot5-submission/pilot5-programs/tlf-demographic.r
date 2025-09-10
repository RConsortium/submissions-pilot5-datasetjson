# Note to Reviewer
# To rerun the code below, please refer ADRG appendix.
# After required package are installed.

## -----------------------------------------------------------------------------
# Working directory requires write permission
if (file.access(".", 2) != 0) {
  warning(
    "The working directory '", normalizePath("."), "' is not writable.\n",
    "Please change it to a location with write permission."
  )
}


## ----setup, message=FALSE-----------------------------------------------------
# CRAN package, please using install.packages() to install
library(haven)
library(dplyr)
library(rtables)

## -----------------------------------------------------------------------------
adsl <- readRDS(file.path(path$adam, "adsl.rds"))

vars <- c("AGE", "AGEGR1", "RACE", "HEIGHTBL", "WEIGHTBL", "BMIBL", "MMSETOT")
lbls <- c(
  "Age", "Pooled Age Group 1", "Race", "Baseline Height (cm)",
  "Baseline Weight (kg)", "Baseline BMI (kg/m^2)", "MMSE Total"
)

## -----------------------------------------------------------------------------
adsl <- adsl %>%
  filter(
    STUDYID == "CDISCPILOT01",
    ITTFL == "Y"
  ) %>%
  mutate(
    TRT01P = factor(TRT01P, levels = c(
      "Placebo", "Xanomeline Low Dose",
      "Xanomeline High Dose"
    )),
    AGEGR1 = factor(AGEGR1, levels = c("<65", "65-80", ">80")),
    RACE = factor(RACE, levels = c(
      "WHITE", "BLACK OR AFRICAN AMERICAN",
      "AMERICAN INDIAN OR ALASKA NATIVE"
    ))
  )

## -----------------------------------------------------------------------------
# Table layout

tbl <- basic_table(
  title = "Protocol: CDISCPILOT01",
  subtitles = "Population: Intent-to-Treat",
  main_footer = paste0("Program: tlf-demographic.r \n", Sys.time())
) %>%
  split_cols_by("TRT01P") %>%
  add_colcounts() %>%
  analyze(vars, function(x, ...) {
    if (is.numeric(x)) {
      in_rows(
        "Mean (sd)" = c(mean(x), sd(x)),
        "Median" = median(x),
        "Min - Max" = range(x),
        .formats = c("xx.xx (xx.xx)", "xx.xx", "xx.xx - xx.xx")
      )
    } else if (is.factor(x) || is.character(x)) {
      in_rows(.list = list_wrap_x(table)(x))
    } else {
      stop("type not supproted")
    }
  },
  var_labels = lbls
  ) %>%
  build_table(df = adsl)

tbl

if (!dir.exists(file.path(path$output, "out"))) {
  dir.create(file.path(path$output, "out"))
}

## -----------------------------------------------------------------------------
# Output .out file
tbl %>%
  toString() %>%
  writeLines(con = file.path(path$output, "out/tlf-demographic-pilot5.out"))
