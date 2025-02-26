# Note to Reviewer
# To rerun the code below, please refer ADRG appendix.
# After required package are installed.
# The path variable needs to be defined by using example code below
#
# nolint start
# path <- list(
# sdtm = "path/to/esub/tabulations/sdtm", # Modify path to the sdtm location
# adam = "path/to/esub/analysis/adam"     # Modify path to the adam location
# )
# nolint end

###########################################################################
#' developers : Steven Haesendonckx/Bingjun Wang/Ben Straub
#' date: 13NOV2022
#' modification History:
###########################################################################

# Set up ------------------------------------------------------------------

library(haven)
library(admiral)
library(dplyr)
library(tidyr)
library(metacore)
library(metatools)
library(pilot5utils)
library(xportr)
library(datasetjson)

# read source -------------------------------------------------------------

adsl <- read_xpt(file.path(path$adam, "adsl.xpt"))
adae <- read_xpt(file.path(path$adam, "adae.xpt"))
ds <- convert_blanks_to_na(read_xpt(file.path(path$sdtm, "ds.xpt")))


# Get the specifications for the dataset we are currently building

adtte_spec <- spec_to_metacore(path = file.path(path$adam, "adam-pilot-5.xlsx"), where_sep_sheet = FALSE) %>%
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
    new_vars = exprs(EOSDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE" & DSDECOD != "FINAL LAB VISIT"
  ) %>%
  # Analysis uses DEATH date rather than discontinuation when subject dies even if discontinuation occurs before death
  # Observed through QC - However not described in specs
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

# Finalize dataset + add common variables ---------------------------------

pre_adtte <- derive_param_tte(
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

# Export dataset to xpt ---------------------------------------------------

var_spec <- data.frame(
  dataset = "adtte",
  label = "AE Time To 1st Derm. Event Analysis",
  data_label = "ADTTE"
)

adtte <- pre_adtte %>%
  drop_unspec_vars(adtte_spec) %>% # only keep vars from define
  order_cols(adtte_spec) %>% # order columns based on define
  set_variable_labels(adtte_spec) %>% # apply variable labels based on define
  xportr_format(adtte_spec$var_spec %>%
                  mutate_at(c("format"), ~ replace_na(., "")), "ADTTE")
xportr_write(adtte,
             path = file.path(path$adam, "adtte.xpt"),
             domain = "adtte",
             max_size_gb = 4, # PMDA submission restriction
             metadata = var_spec,
             strict_checks = FALSE
)

# Export dataset to JSON ---------------------------------------------------

sysinfo <- unname(Sys.info()) 

adtte_spec$value_spec

ds_json <- dataset_json(
  adtte,
  file_oid = path$adam,
  last_modified = strftime(as.POSIXlt(Sys.time(), "UTC"), "%Y-%m-%dT%H:%M"),
  originator = "Steven Haesendonckx",
  sys = sysinfo[1],
  sys_version = sysinfo[3],
  study = "CDSICPILOT01",
  metadata_version = "MDV.MSGv2.0.SDTMIG.3.3.SDTM.1.7",
  metadata_ref = "some/define.xml",
  item_oid = "IG.IRIS",
  name = "ADTTE",
  dataset_label = "AE Time To 1st Derm. Event Analysis",
  columns = adtte_spec$value_spec
)


# End ---------------------------------------------------------------------
