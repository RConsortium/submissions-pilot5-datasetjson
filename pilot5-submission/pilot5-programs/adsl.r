###########################################################################
#' developers : Steven Haesendonckx/Declan Hodges/Thomas Neitmann
#' date: 09DEC2022
#' modification History:Sai janardhan
#' date:31MAR2025
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
library(janitor)
library(datasetjson)

# read source -------------------------------------------------------------
# When SAS datasets are imported into R using read_sas(), missing
# character values from SAS appear as "" characters in R, instead of appearing
# as NA values. Further details can be obtained via the following link:
# https://pharmaverse.github.io/admiral/articles/admiral.html#handling-of-missing-values


dm <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "dm.rds")))
ds <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "ds.rds")))
ex <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "ex.rds")))
qs <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "qs.rds")))
sv <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "sv.rds")))
vs <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "vs.rds")))
sc <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "sc.rds")))
mh <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "mh.rds")))



## placeholder for origin=predecessor, use metatool::build_from_derived()
metacore <- spec_to_metacore(file.path(path$adam, "adam-pilot-5.xlsx"), where_sep_sheet = FALSE)
# Get the specifications for the dataset we are currently building
adsl_spec <- metacore %>%
  select_dataset("ADSL")

ds00 <- ds %>%
  filter(DSCAT == "DISPOSITION EVENT", DSDECOD != "SCREEN FAILURE") %>%
  derive_vars_dt(
    dtc = DSSTDTC,
    new_vars_prefix = "EOS",
    highest_imputation = "n",
  ) %>%
  mutate(
    DISCONFL = ifelse(!is.na(EOSDT) & DSDECOD != "COMPLETED", "Y", NA),
    DSRAEFL = ifelse(DSTERM == "ADVERSE EVENT", "Y", NA),
    DCDECOD = DSDECOD
  ) %>%
  select(STUDYID, USUBJID, EOSDT, DISCONFL, DSRAEFL, DSDECOD, DSTERM, DCDECOD)


# Treatment information ---------------------------------------------------

mh <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "mh.rds")))

mh <- derive_vars_dt(
  mh,
  dtc = MHDTC,
  new_vars_prefix = "AST",
  highest_imputation = "M",
)

colnames(mh)
mh[, c("MHDTC", "ASTDT")]


ex_dt <- ex %>%
  derive_vars_dt(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    highest_imputation = "n",
  ) %>%
  # treatment end is imputed by discontinuation if subject discontinued after visit 3 = randomization as per protocol
  derive_vars_merged(
    dataset_add = ds00,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(EOSDT = EOSDT),
    filter_add = DCDECOD != "COMPLETED"
  ) %>%
  derive_vars_dt(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    highest_imputation = "Y",
    max_dates = exprs(EOSDT),
    date_imputation = "last",
    flag_imputation = "none"
  ) %>%
  mutate(DOSE = EXDOSE * (EXENDT - EXSTDT + 1))

ex_dose <- ex_dt %>%
  group_by(STUDYID, USUBJID, EXTRT) %>%
  summarise(cnt = n_distinct(EXTRT), CUMDOSE = sum(DOSE))

ex_dose[which(ex_dose[["cnt"]] > 1), "USUBJID"] # are there subjects with mixed treatments?

adsl00 <- dm %>%
  select(-DOMAIN) %>%
  filter(ACTARMCD != "Scrnfail") %>%
  # planned treatment
  mutate(
    TRT01P = ARM,
    TRT01PN = case_when(
      ARM == "Placebo" ~ 0,
      ARM == "Xanomeline High Dose" ~ 81,
      ARM == "Xanomeline Low Dose" ~ 54
    )
  ) %>%
  # actual treatment - It is assumed TRT01A=TRT01P which is not really true.
  mutate(
    TRT01A = TRT01P,
    TRT01AN = TRT01PN
  ) %>%
  # treatment start
  derive_vars_merged(
    dataset_add = ex_dt,
    filter_add = (
      EXDOSE > 0 |
        (EXDOSE == 0 & grepl("PLACEBO", EXTRT, fixed = TRUE))
    ) &
      !is.na(EXSTDT),
    new_vars = exprs(TRTSDT = EXSTDT),
    order = exprs(EXSTDT, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  # treatment end
  derive_vars_merged(
    dataset_add = ex_dt,
    filter_add = (
      EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", EXTRT, fixed = TRUE))
    ) &
      !is.na(EXENDT),
    new_vars = exprs(TRTEDT = EXENDT),
    order = exprs(EXENDT, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  # treatment duration
  derive_var_trtdurd() %>%
  # dosing
  left_join(ex_dose, by = c("STUDYID", "USUBJID")) %>%
  select(-cnt) %>%
  mutate(AVGDD = round_half_up(as.numeric(CUMDOSE) / TRTDURD, digits = 1))

# Demographic grouping ----------------------------------------------------
adsl01 <- adsl00 %>%
  create_cat_var(adsl_spec, AGE, AGEGR1, AGEGR1N) %>%
  create_var_from_codelist(adsl_spec, RACE, RACEN)



# Population flag ---------------------------------------------------------
# SAFFL - Y if ITTFL='Y' and TRTSDT ne missing. N otherwise
# ITTFL - Y if ARMCD ne ' '. N otherwise
# EFFFL - Y if SAFFL='Y AND at least one record in QS for ADAS-Cog and for CIBIC+ with VISITNUM>3, N otherwise
# these variables are also in suppdm, but define said derived

qstest <- distinct(qs[, c("QSTESTCD", "QSTEST")])

eff <- qs %>%
  filter(VISITNUM > 3, QSTESTCD %in% c("CIBIC", "ACTOT")) %>%
  group_by(STUDYID, USUBJID) %>%
  summarise(effcnt = n_distinct(QSTESTCD))

adsl02 <- adsl01 %>%
  left_join(eff, by = c("STUDYID", "USUBJID")) %>%
  mutate(
    SAFFL = case_when(
      ARMCD != "Scrnfail" & ARMCD != "" & !is.na(TRTSDT) ~ "Y",
      ARMCD == "Scrnfail" ~ NA_character_,
      TRUE ~ "N"
    ),
    ITTFL = case_when(
      ARMCD != "Scrnfail" & ARMCD != "" ~ "Y",
      ARMCD == "Scrnfail" ~ NA_character_,
      TRUE ~ "N"
    ),
    EFFFL = case_when(
      ARMCD != "Scrnfail" & ARMCD != "" & !is.na(TRTSDT) & effcnt == 2 ~ "Y",
      ARMCD == "Scrnfail" ~ NA_character_,
      TRUE ~ "N"
    )
  )

# Study Visit compliance --------------------------------------------------
# these variables are also in suppdm, but define said derived

sv00 <- sv %>%
  select(STUDYID, USUBJID, VISIT, VISITDY, SVSTDTC) %>%
  mutate(
    FLG = "Y",
    VISITCMP = case_when(
      VISIT == "WEEK 8" ~ "COMP8FL",
      VISIT == "WEEK 16" ~ "COMP16FL",
      VISIT == "WEEK 24" ~ "COMP24FL",
      TRUE ~ "ZZZ" # ensures every subject with one visit will get a row with minimally 'N'
    )
  ) %>%
  arrange(STUDYID, USUBJID, VISITDY) %>%
  distinct(STUDYID, USUBJID, VISITCMP, FLG) %>%
  pivot_wider(names_from = VISITCMP, values_from = FLG, values_fill = "N") %>%
  select(-ZZZ)

adsl03 <- adsl02 %>%
  left_join(sv00, by = c("STUDYID", "USUBJID"))

# Disposition -------------------------------------------------------------



adsl04 <- adsl03 %>%
  left_join(ds00, by = c("STUDYID", "USUBJID")) %>%
  select(-DSDECOD) %>%
  derive_vars_merged(
    dataset_add = ds00,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(EOSSTT = DSDECOD),
    filter_add = !is.na(USUBJID)
  ) %>%
  mutate(EOSSTT = if_else(DCDECOD == "COMPLETED", "COMPLETED", "DISCONTINUED")) %>%
  derive_vars_merged(
    dataset_add = ds00,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(DCSREAS = DSDECOD),
    filter_add = !is.na(USUBJID)
  ) %>%
  mutate(DCSREAS = case_when(
    DCDECOD != "COMPLETED" & DSTERM == "PROTOCOL ENTRY CRITERIA NOT MET" ~ "I/E Not Met",
    DCDECOD != "COMPLETED" ~ DCSREAS,
    TRUE ~ ""
  ))


# Baseline variables ------------------------------------------------------
# selection definition from define

vs00 <- vs %>%
  filter((VSTESTCD == "HEIGHT" & VISITNUM == 1) | (VSTESTCD == "WEIGHT" & VISITNUM == 3)) %>%
  mutate(AVAL = round_half_up(VSSTRESN, digits = 1)) %>%
  select(STUDYID, USUBJID, VSTESTCD, AVAL) %>%
  pivot_wider(names_from = VSTESTCD, values_from = AVAL, names_glue = "{VSTESTCD}BL") %>%
  mutate(
    BMIBL = round_half_up(WEIGHTBL / (HEIGHTBL / 100)^2, digits = 1)
  ) %>%
  create_cat_var(adsl_spec, BMIBL, BMIBLGR1)

sc00 <- sc %>%
  filter(SCTESTCD == "EDLEVEL") %>%
  select(STUDYID, USUBJID, SCTESTCD, SCSTRESN) %>%
  pivot_wider(names_from = SCTESTCD, values_from = SCSTRESN, names_glue = "EDUCLVL")

adsl05 <- adsl04 %>%
  left_join(vs00, by = c("STUDYID", "USUBJID")) %>%
  left_join(sc00, by = c("STUDYID", "USUBJID"))

# Disease information -----------------------------------------------------

visit1dt <- sv %>%
  filter(VISITNUM == 1) %>%
  derive_vars_dt(
    dtc = SVSTDTC,
    new_vars_prefix = "VISIT1",
  ) %>%
  select(STUDYID, USUBJID, VISIT1DT)

visnumen <- sv %>%
  filter(VISITNUM < 100) %>%
  arrange(STUDYID, USUBJID, SVSTDTC) %>%
  group_by(STUDYID, USUBJID) %>%
  slice(n()) %>%
  ungroup() %>%
  mutate(VISNUMEN = ifelse(round_half_up(VISITNUM, digits = 0) == 13, 12, round_half_up(VISITNUM, digits = 0))) %>%
  select(STUDYID, USUBJID, VISNUMEN)

disonsdt <- mh %>%
  filter(MHCAT == "PRIMARY DIAGNOSIS") %>%
  derive_vars_dt(
    dtc = MHSTDTC,
    new_vars_prefix = "DISONS",
  ) %>%
  select(STUDYID, USUBJID, DISONSDT)

adsl06 <- adsl05 %>%
  left_join(visit1dt, by = c("STUDYID", "USUBJID")) %>%
  left_join(visnumen, by = c("STUDYID", "USUBJID")) %>%
  left_join(disonsdt, by = c("STUDYID", "USUBJID")) %>%
  derive_vars_duration(
    new_var = DURDIS,
    start_date = DISONSDT,
    end_date = VISIT1DT,
    out_unit = "days",
    add_one = TRUE
  ) %>%
  # derive_vars_duration(..., out_unit = "months") is not used here because
  # it calculates months based on date internals, while the original CDISC
  # adsl.DURDIS was derived assuming each month has the same number of days,
  # i.e., 365.25/12=30.4375.
  # Feature requested: https://github.com/pharmaverse/admiral/issues/1875
  # Workaround: derive days first and then convert it to months
  mutate(
    DURDIS = round_half_up(DURDIS / (365.25 / 12), digits = 1)
  ) %>%
  create_cat_var(adsl_spec, DURDIS, DURDSGR1) %>%
  derive_vars_dt(
    dtc = RFENDTC,
    new_vars_prefix = "RFEN",
  )

mmsetot <- qs %>%
  filter(QSCAT == "MINI-MENTAL STATE") %>%
  group_by(STUDYID, USUBJID) %>%
  summarise(MMSETOT = sum(as.numeric(QSORRES), na.rm = TRUE)) %>%
  select(STUDYID, USUBJID, MMSETOT)

adsl07 <- adsl06 %>%
  left_join(mmsetot, by = c("STUDYID", "USUBJID"))


# generating the SITEGR1 variable
# Grouping by SITEID, TRT01A to get the count fewer than 3 patients in any one treatment group.

adsl07_ <- adsl07 %>%
  group_by(SITEID, TRT01A) %>%
  count(SITEID) %>%
  ungroup(SITEID, TRT01A)



adsl07 <- left_join(adsl07, adsl07_, by = c("SITEID", "TRT01A")) %>%
  mutate(SITEGR1 = if_else(n <= 3, "900", SITEID)) %>%
  select(-n)




# Export to xpt -----------------------------------------------------
adsl <- adsl07 %>%
  drop_unspec_vars(adsl_spec) %>%
  check_ct_data(adsl_spec, na_acceptable = TRUE) %>%
  order_cols(adsl_spec) %>%
  sort_by_key(adsl_spec) %>%
  xportr_length(adsl_spec) %>%
  xportr_label(adsl_spec) %>%
  xportr_df_label(adsl_spec, domain = "adsl") %>%
  xportr_format(
    adsl_spec$var_spec %>%
      mutate_at(c("format"), ~ replace_na(., "")),
    "ADSL"
  )


# saving the dataset as rds format
saveRDS(adsl, file.path(path$adam, "adsl.rds"))
