#************************************************************************
# Purpose:     Generate ADTTE dataset
# Input:       DS (from datasetjson), ADSL, and ADAE datasets
# Output:      adtte.json
#************************************************************************

# Note to Reviewer
# To rerun the code below, please refer ADRG appendix.
# After required package are installed, the path variable needs to be defined
# in the .Rprofile file

# Setup -----------------
## Load libraries -------
library(dplyr)
library(tidyr)
library(admiral)
library(metacore)
library(metatools)
library(datasetjson)

## Load datasets ------------
dat_to_load <- list(
  ds = file.path(path$sdtm, "ds.json"),
  adsl = file.path(path$adam_json, "adsl.json"),
  adae = file.path(path$adam_json, "adae.json")
)

datasets <- map(
  dat_to_load,
  ~ convert_blanks_to_na(read_dataset_json(.x, decimals_as_floats = TRUE))
)

list2env(datasets, envir = .GlobalEnv)

## Load dataset specs -----------
metacore <- spec_to_metacore(file.path(path$adam, "adam-pilot-5.xlsx"),
  where_sep_sheet = FALSE,
  quiet = TRUE
)

### Get the specifications for the dataset we are currently building
adtte_spec <- metacore %>%
  select_dataset("ADTTE")

# Create ADTTE dataset -----------------
## Add supplemental information ----------
### First dermatological event (ADAE.AOCC01FL = 'Y' and ADAE.CQ01NAM != '')
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

## Censor events ---------------------------------------------------------
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
    new_vars = exprs(EOSDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" &
      DSDECOD != "SCREEN FAILURE" &
      DSDECOD != "FINAL LAB VISIT"
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
  ) %>%
  mutate(CNSR = as.numeric(CNSR))

# Export to xpt ----------------
adtte <- adtte_pre %>%
  drop_unspec_vars(adtte_spec) %>%
  check_ct_data(adtte_spec, na_acceptable = TRUE) %>%
  order_cols(adtte_spec) %>%
  sort_by_key(adtte_spec) %>%
  set_variable_labels(adtte_spec) %>%
  xportr_label(adtte_spec) %>%
  xportr_df_label(adtte_spec, domain = "adtte") %>%
  xportr_format(
    adtte_spec$var_spec %>% mutate_at(c("format"), ~ replace_na(., "")),
    "ADTTE"
  ) %>%
  convert_na_to_blanks()

# FIX: attribute issues where sas.format attributes set to DATE9. are changed to DATE9,
# and missing formats are set to NULL (instead of an empty character vector)
# when reading original xpt file
for (col in colnames(adtte)) {
  if (attr(adtte[[col]], "format.sas") == "") {
    attr(adtte[[col]], "format.sas") <- NULL
  } else if (attr(adtte[[col]], "format.sas") == "DATE9.") {
    attr(adtte[[col]], "format.sas") <- "DATE9"
  }
}

# Saving the dataset as datasetjson format --------------
# Prepare column metadata for JSON
oid_cols <- adtte_spec$ds_vars %>%
  select(dataset, variable, key_seq) %>%
  left_join(adtte_spec$var_spec, by = c("variable")) %>%
  rename(name = variable, dataType = type, keySequence = key_seq, displayFormat = format) %>%
  mutate(itemOID = paste0("IT.", dataset, ".", name)) %>%
  select(itemOID, name, label, dataType, length, keySequence, displayFormat) %>%
  mutate(
    dataType =
      case_when(
        displayFormat == "DATE9." ~ "date",
        displayFormat == "DATETIME20." ~ "datetime",
        substr(name, nchar(name) - 3 + 1, nchar(name)) == "DTC" & length == "8" ~ "date",
        substr(name, nchar(name) - 3 + 1, nchar(name)) == "DTC" & length == "20" ~ "datetime",
        dataType == "text" ~ "string",
        .default = as.character(dataType)
      ),
    targetDataType =
      case_when(
        displayFormat == "DATE9." ~ "integer",
        displayFormat == "DATETIME20." ~ "integer",
        .default = NA
      ),
    length = case_when(
      dataType == "string" ~ length,
      .default = NA
    )
  ) %>%
  data.frame()

# Write as datasetjson
dataset_json(adtte,
  last_modified = strftime(as.POSIXlt(Sys.time(), "UTC"), "%Y-%m-%dT%H:%M"),
  originator = "R Submission Pilot 5",
  sys = paste0("R on ", R.Version()$os, " ", unname(Sys.info())[[2]]),
  sys_version = R.Version()$version.string,
  version = "1.1.0",
  study = "Pilot 5",
  metadata_version = "MDV.TDF_ADaM.ADaM-IG.1.1",
  metadata_ref = file.path(path$adam, "define.xml"),
  item_oid = paste0("IG.ADTTE"),
  name = "ADTTE",
  dataset_label = adtte_spec$ds_spec[["label"]],
  file_oid = file.path(path$adam, "adtte"),
  columns = oid_cols
) %>%
  write_dataset_json(file = file.path(path$adam_json, "adtte.json"), float_as_decimals = TRUE)
