#************************************************************************
# Purpose:     Generate ADAE dataset
# Input:       AE, SUPPAE, and ADSL datasets
# Output:      adae.rds
#************************************************************************

# Note to Reviewer
# To rerun the code below, please refer ADRG appendix.
# After required package are installed, the path variable needs to be defined
# in the .Rprofile file

# Setup -----------------
## Load libraries -------
library(admiral)
library(dplyr)
library(tidyr)
library(stringr)
library(xportr)
library(metacore)
library(metatools)
library(haven)

## Load datasets ------------
dat_to_load <- list(
  ae = file.path(path$sdtm, "ae.rds"),
  suppae = file.path(path$sdtm, "suppae.rds"),
  adsl = file.path(path$adam, "adsl.rds")
)

datasets <- map(
  dat_to_load,
  ~ convert_blanks_to_na(readRDS(.x))
)

list2env(datasets, envir = .GlobalEnv)

## Load dataset specs -----------
metacore <- spec_to_metacore(
  file.path(path$adam, "adam-pilot-5.xlsx"),
  where_sep_sheet = FALSE
)

### Get the specifications for the dataset we are currently building
adae_spec <- metacore %>%
  select_dataset("ADAE")

# Create ADAE dataset -----------------
## Get list of ADSL vars
adsl_vars <- exprs(
  TRTSDT,
  TRTEDT,
  STUDYID,
  SITEID,
  TRT01A,
  TRT01AN,
  AGE,
  AGEGR1,
  AGEGR1N,
  RACE,
  RACEN,
  SEX,
  SAFFL,
  TRTSDT,
  TRTEDT
)

## Merge adsl to ae
adae0 <- ae %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = adsl_vars,
    by = exprs(STUDYID, USUBJID)
  ) %>%
  # Set TRTA and TRTAN from ADSL
  rename(
    TRTA = TRT01A,
    TRTAN = TRT01AN
  ) %>%
  # Derive analysis start time
  derive_vars_dtm(
    dtc = AESTDTC,
    new_vars_prefix = "AST",
    highest_imputation = "D"
  ) %>%
  # Derive analysis end time
  derive_vars_dtm(
    dtc = AEENDTC,
    new_vars_prefix = "AEN",
    highest_imputation = "h",
    max_dates = NULL
  ) %>%
  # Derive analysis start & end dates
  derive_vars_dtm_to_dt(exprs(ASTDTM, AENDTM)) %>%
  # Duration of AE
  derive_vars_dy(
    reference_date = TRTSDT,
    source_vars = exprs(TRTSDT, ASTDT, AENDT)
  ) %>%
  derive_vars_duration(
    new_var = ADURN,
    new_var_unit = ADURU,
    start_date = ASTDT,
    end_date = AENDT,
    out_unit = "DAYS"
  ) %>%
  # Treatment Emergent Analysis flag
  restrict_derivation(
    derivation = derive_var_trtemfl,
    args = params(
      start_date = ASTDT,
      end_date = AENDT,
      trt_start_date = TRTSDT
    ),
    filter = !is.na(ASTDT)
  ) %>%
  # AOCCFL - 1st Occurrence of Any AE Flag
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCCFL,
      mode = "first"
    ), filter = TRTEMFL == "Y"
  ) %>%
  # AOCCSFL - 1st Occurrence of SOC Flag
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, AEBODSYS),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCCSFL,
      mode = "first"
    ), filter = TRTEMFL == "Y"
  ) %>%
  # AOCCPFL - 1st Occurrence of Preferred Term Flag
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, AEBODSYS, AEDECOD),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCCPFL,
      mode = "first"
    ), filter = TRTEMFL == "Y"
  ) %>%
  # AOCC02FL - 1st Occurrence 02 Flag for Serious
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCC02FL,
      mode = "first"
    ), filter = TRTEMFL == "Y" & AESER == "Y"
  ) %>%
  # AOCC03FL - 1st Occurrence 03 Flag for Serious SOC
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, AEBODSYS),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCC03FL,
      mode = "first"
    ), filter = TRTEMFL == "Y" & AESER == "Y"
  ) %>%
  # AOCC04FL - 1st Occurrence 04 Flag for Serious PT
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, AEBODSYS, AEDECOD),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCC04FL,
      mode = "first"
    ), filter = TRTEMFL == "Y" & AESER == "Y"
  ) %>%
  # CQ01NAM - Customized Query 01 Name
  mutate(CQ01NAM = ifelse(
    str_detect(AEDECOD, "APPLICATION") |
      str_detect(AEDECOD, "DERMATITIS") |
      str_detect(AEDECOD, "ERYTHEMA") |
      str_detect(AEDECOD, "BLISTER") |
      str_detect(AEBODSYS, "SKIN AND SUBCUTANEOUS TISSUE DISORDERS") &
        !str_detect(AEDECOD, "COLD SWEAT|HYPERHIDROSIS|ALOPECIA"),
    "DERMATOLOGIC EVENTS",
    NA_character_
  )) %>%
  # AOCC01FL - 1st Occurrence 01 Flag for CQ01
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID),
      order = exprs(ASTDT, AESEQ),
      new_var = AOCC01FL,
      mode = "first"
    ), filter = TRTEMFL == "Y" & CQ01NAM == "DERMATOLOGIC EVENTS"
  )

# Export to xpt ---------------
adae <- adae0 %>%
  drop_unspec_vars(adae_spec) %>%
  check_ct_data(adae_spec, na_acceptable = TRUE) %>%
  order_cols(adae_spec) %>%
  sort_by_key(adae_spec) %>%
  set_variable_labels(adae_spec) %>%
  xportr_df_label(adae_spec, domain = "ADAE") %>%
  xportr_label(adae_spec) %>%
  xportr_format(adae_spec$var_spec, "ADAE") %>%
  convert_na_to_blanks()

# FIX: attribute issues where sas.format attributes set to DATE9. are changed to DATE9,
# and missing formats are set to NULL (instead of an empty character vector)
# when reading original xpt file
for (col in colnames(adae)) {
  if (attr(adae[[col]], "format.sas") == "") {
    attr(adae[[col]], "format.sas") <- NULL
  } else if (attr(adae[[col]], "format.sas") == "DATE9.") {
    attr(adae[[col]], "format.sas") <- "DATE9"
  }
}

# Saving the dataset as rds format -------
saveRDS(adae, file.path(path$adam, "adae.rds"))
