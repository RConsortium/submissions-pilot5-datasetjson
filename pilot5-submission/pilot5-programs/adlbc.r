#************************************************************************
# Purpose:     Generate ADLBC dataset
# Input:       LB, SUPPLB (from datasetjson), and ADSL datasets
# Output:      adlbc.json
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
library(stringr)
library(purrr)
library(datasetjson)

## Load datasets ------------
dat_to_load <- list(
  lb = file.path(path$sdtm, "lb.json"),
  supplb = file.path(path$sdtm, "supplb.json"),
  adsl = file.path(path$adam_json, "adsl.json")
)

datasets <- map(
  dat_to_load,
  ~ convert_blanks_to_na(read_dataset_json(.x, decimals_as_floats = TRUE))
)

list2env(datasets, envir = .GlobalEnv)

## Load dataset specs -----------
metacore <- spec_to_metacore(
  file.path(path$adam, "adam-pilot-5.xlsx"),
  where_sep_sheet = FALSE,
  quiet = TRUE
)

### Get the specifications for the dataset we are currently building
adlbc_spec <- metacore %>%
  select_dataset("ADLBC")

# Create ADLBC dataset -----------------
## Add supplemental information ----------
sup <- supplb %>%
  select(STUDYID, USUBJID, IDVAR, IDVARVAL, QNAM, QLABEL, QVAL) %>%
  pivot_wider(
    id_cols = c(STUDYID, USUBJID, IDVARVAL),
    names_from = QNAM,
    values_from = QVAL
  ) %>%
  mutate(LBSEQ = as.numeric(IDVARVAL)) %>%
  select(-IDVARVAL)

adlb00 <- lb %>%
  left_join(sup, by = c("STUDYID", "USUBJID", "LBSEQ")) %>%
  filter(LBCAT == "CHEMISTRY")

## ADSL information ----------------------------------------------
adsl_vars <- exprs(
  STUDYID,
  SUBJID,
  USUBJID,
  TRT01PN,
  TRT01P,
  TRT01AN,
  TRT01A,
  TRTSDT,
  TRTEDT,
  AGE,
  AGEGR1,
  AGEGR1N,
  RACE,
  RACEN,
  SEX,
  COMP24FL,
  DSRAEFL,
  SAFFL
)

adlb01 <- adlb00 %>%
  derive_vars_merged(
    dataset_add = adsl,
    new_vars = adsl_vars,
    by = exprs(STUDYID, USUBJID)
  )

## Dates -------------------------------------------
adlb02 <- adlb01 %>%
  derive_vars_dt(
    new_vars_prefix = "A",
    dtc = LBDTC,
    highest_imputation = "n"
  ) %>%
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT))

## AVAL(C) ------------------------------------------------
# No imputations are done for values below LL or above UL
adlb03 <- adlb02 %>%
  mutate(
    AVAL = LBSTRESN,
    AVALC = ifelse(!is.na(AVAL), LBSTRESC, NA)
  )

## Parameter --------------------------------------------
adlb04 <- adlb03 %>%
  mutate(
    PARAM = paste0(LBTEST, " (", LBSTRESU, ")"),
    PARAMCD = LBTESTCD,
    PARCAT1 = "CHEM"
  ) %>%
  create_var_from_codelist(
    metacore = adlbc_spec,
    input_var = PARAM,
    out_var = PARAMN
  )

## Baseline ----------------------------------
adlb05 <- adlb04 %>%
  mutate(ABLFL = LBBLFL) %>%
  derive_var_base(
    by_vars = exprs(STUDYID, USUBJID, PARAMCD),
    source_var = AVAL,
    new_var = BASE
  ) %>%
  derive_var_chg() %>%
  mutate(CHG = ifelse(VISITNUM == 1, NA, CHG))


## Visits ------------------------------
eot <- adlb05 %>%
  filter(ENDPOINT == "Y" | VISITNUM == 12) %>%
  mutate(
    AVISIT = "End of Treatment",
    AVISITN = 99,
    AENTMTFL = "Y"
  )

adlb06 <- adlb05 %>%
  # nolint start
  filter(grepl("WEEK", VISIT, fixed = TRUE) |
    grepl("UNSCHEDULED", VISIT, fixed = TRUE) |
    grepl("SCREENING", VISIT, fixed = TRUE)) %>%
  # nolint end
  mutate(
    AVISIT = case_when(
      ABLFL == "Y" ~ "Baseline",
      grepl("UNSCHEDULED", VISIT) == TRUE ~ "",
      TRUE ~ str_to_sentence(VISIT)
    ),
    AVISITN = case_when(
      AVISIT == "Baseline" ~ 0,
      TRUE ~ as.numeric(gsub("[^0-9]", "", AVISIT))
    ),
    AENTMTFL = ""
  ) %>%
  rbind(eot) %>%
  mutate(
    AVISITN = ifelse(AVISITN == -1, "", AVISITN)
  )

# get EOT for those that did not make it to week 24
eot2 <- adlb06 %>%
  arrange(STUDYID, USUBJID, PARAMCD, desc(AVISITN)) %>%
  group_by(STUDYID, USUBJID, PARAMCD) %>%
  filter(VISITNUM != 13) %>%
  slice(1) %>%
  filter(!is.na(AVISITN), AVISITN != 0, AVISITN != 99) %>%
  mutate(
    AVISITN = 99,
    AVISIT = "End of Treatment",
    AENTMTFL = "Y"
  )

adlb07 <- adlb06 %>%
  filter(VISITNUM <= 12 & AVISITN > 0 & AVISITN != 99 & !grepl("UN", VISIT)) %>%
  group_by(USUBJID, PARAMCD) %>%
  mutate(AENTMTFL_1 = ifelse(max(AVISITN, na.rm = TRUE) == AVISITN, "Y", "")) %>%
  select(USUBJID, PARAMCD, AENTMTFL_1, LBSEQ) %>%
  full_join(adlb06, by = c("USUBJID", "PARAMCD", "LBSEQ"), multiple = "all") %>%
  mutate(AENTMTFL = ifelse(AENTMTFL == "Y", AENTMTFL, AENTMTFL_1)) %>%
  select(-AENTMTFL_1) %>%
  rbind(eot2) %>%
  ungroup()

## Limits -----------------------------------
adlb08 <- adlb07 %>%
  mutate(
    ANRLO = LBSTNRLO,
    ANRHI = LBSTNRHI,
    A1LO = LBSTNRLO,
    A1HI = LBSTNRHI,
    R2A1LO = AVAL / A1LO,
    R2A1HI = AVAL / A1HI,
    BR2A1LO = BASE / A1LO,
    BR2A1HI = BASE / A1HI,
    ONE = abs((LBSTRESN - (1.5 * LBSTNRHI))),
    TWO = abs(((.5 * LBSTNRLO) - LBSTRESN)),
    ALBTRVAL = ifelse(ONE > TWO, ONE, TWO),
    ANRIND = ifelse(AVAL < (0.5 * LBSTNRLO), "L", ifelse(AVAL > (1.5 * LBSTNRHI), "H", "N")),
    ANRIND = ifelse(is.na(AVAL), "N", ANRIND)
  ) %>%
  derive_var_base(
    by_vars = exprs(STUDYID, USUBJID, PARAMCD),
    source_var = ANRIND,
    new_var = BNRIND
  ) %>% # Low and High values are repeating
  group_by(STUDYID, USUBJID, PARAMCD) %>%
  ungroup() %>%
  select(-ONE, -TWO)

## Derive ANL01FL -----------
adlb09 <- adlb08 %>%
  filter((VISITNUM >= 4 & VISITNUM <= 12) & !grepl("UN", VISIT)) %>%
  group_by(USUBJID, PARAMCD) %>%
  mutate(
    maxALBTRVAL = ifelse(!is.na(ALBTRVAL), max(ALBTRVAL, na.rm = TRUE), ALBTRVAL),
    ANL01FL = ifelse(maxALBTRVAL == ALBTRVAL, "Y", "")
  ) %>%
  arrange(desc(ANL01FL)) %>%
  select(USUBJID, PARAMCD, LBSEQ, ANL01FL) %>%
  slice(1) %>%
  full_join(adlb08, by = c("USUBJID", "PARAMCD", "LBSEQ"), multiple = "all")

# Export to xpt ---------------
adlbc10 <- adlb09 %>%
  mutate(
    TRTP = TRT01P,
    TRTPN = TRT01PN,
    TRTA = TRT01A,
    TRTAN = TRT01AN
  )

adlbc <- adlbc10 %>%
  drop_unspec_vars(adlbc_spec) %>%
  check_ct_data(adlbc_spec, na_acceptable = TRUE) %>%
  order_cols(adlbc_spec) %>%
  convert_na_to_blanks() %>%
  set_variable_labels(adlbc_spec) %>%
  xportr_label(adlbc_spec) %>%
  xportr_df_label(adlbc_spec, domain = "adlbc") %>%
  xportr_format(
    adlbc_spec$var_spec %>% mutate_at(c("format"), ~ replace_na(., "")),
    "ADLBC"
  )

# FIX: attribute issues where sas.format attributes set to DATE9. are changed to DATE9,
# and missing formats are set to NULL (instead of an empty character vector)
# when reading original xpt file
for (col in colnames(adlbc)) {
  if (attr(adlbc[[col]], "format.sas") == "") {
    attr(adlbc[[col]], "format.sas") <- NULL
  } else if (attr(adlbc[[col]], "format.sas") == "DATE9.") {
    attr(adlbc[[col]], "format.sas") <- "DATE9"
  }
}

# Saving the dataset as datasetjson format --------------
write_dataset_json_with_metadata(adlbc, adlbc_spec, "adlbc", path$adam_json)
