# Set up ------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(admiral)
library(metacore)
library(metatools)
library(pilot5utils)

# read source -------------------------------------------------------------
ds <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "ds.rds")))
adsl <- convert_blanks_to_na(readRDS(file.path(path$adam, "adsl.rds")))
adae <- convert_blanks_to_na(readRDS(file.path(path$adam, "adae.rds")))

## placeholder for origin=predecessor, use metatool::build_from_derived()
metacore <- spec_to_metacore(file.path(path$adam, "adam-pilot-5.xlsx"), where_sep_sheet = FALSE)

# Get the specifications for the dataset we are currently building
adtte_spec <- metacore %>%
  select_dataset("ADTTE")

# First dermatological event (ADAE.AOCC01FL = 'Y' and ADAE.CQ01NAM != '')
event <- event_source(
  dataset_name = "adae",
  filter = AOCC01FL == "Y" & CQ01NAM == "DERMATOLOGIC EVENTS" & SAFFL == "Y",
  date = ASTDT,
  set_values_to = exprs(
    EVNTDESC = "Dematologic Event Occured",
    SRCDOM = "ADAE",
    SRCVAR = "ASTDT",
    SRCSEQ = AESEQ
  )
)

# Censor events ---------------------------------------------------------

## discontinuation, completed, death
ds00 <- ds %>%
  select(STUDYID, USUBJID, DSCAT, DSDECOD, DSSTDTC) %>%
  derive_vars_dt(
    .,
    dtc = DSSTDTC,
    new_vars_prefix = "DSST"
  )

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds00,
    by_vars = exprs(STUDYID, USUBJID),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE" & DSDECOD != "FINAL LAB VISIT"
  ) %>%
  mutate(EOS2DT = case_when(
    DCDECOD == "DEATH" ~ as.Date(RFENDTC),
    DCDECOD != "DEATH" ~ EOSDT
  ))

censor <- censor_source(
  dataset_name = "adsl",
  date = EOS2DT,
  set_values_to = exprs(
    EVNTDESC = "Study Completion Date",
    SRCDOM = "ADSL",
    SRCVAR = "RFENDT"
  )
)

adtte_pre <- derive_param_tte(
  dataset_adsl = adsl,
  start_date = TRTSDT,
  event_conditions = list(event),
  censor_conditions = list(censor),
  source_datasets = list(adsl = adsl, adae = adae),
  set_values_to = exprs(PARAMCD = "TTDE", PARAM = "Time to First Dermatologic Event")
) %>%
  derive_vars_duration(
    new_var = AVAL,
    start_date = STARTDT,
    end_date = ADT
  ) %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = exprs(
      AGE, AGEGR1, AGEGR1N, RACE, RACEN, SAFFL, SEX, SITEID, TRT01A,
      TRT01AN, TRTDURD, TRTEDT, TRT01P, TRTSDT
    ),
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  rename(
    TRTA = TRT01A,
    TRTAN = TRT01AN,
    TRTDUR = TRTDURD,
    TRTP = TRT01P
  )

adtte_rds <- adtte_pre %>%
  drop_unspec_vars(adtte_spec) %>% # only keep vars from define
  order_cols(adtte_spec) %>% # order columns based on define
  set_variable_labels(adtte_spec) # apply variable labels based on define

## ADTTE Production data
adtte <- adtte_rds %>%
  drop_unspec_vars(adtte_spec) %>% # only keep vars from define
  order_cols(adtte_spec) %>% # order columns based on define
  set_variable_labels(adtte_spec)

# saving the dataset as RDS format
saveRDS(adtte, file.path(path$adam, "adtte.rds"))
