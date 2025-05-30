# Set up ------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(admiral)
library(metacore)
library(metatools)
library(stringr)
library(pilot5utils)

# read source -------------------------------------------------------------
## Laboratory Tests Results (LB)
lb <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "lb.rds")))

## Supplemental Qualifiers for LB (SUPPLB)
supplb <- convert_blanks_to_na(readRDS(file.path(path$sdtm, "supplb.rds")))

# Read and convert NA for ADaM DATASET
## Subject-Level Analysis
adsl <- convert_blanks_to_na(readRDS(file.path(path$adam, "adsl.rds")))

# create labels
metacore <- spec_to_metacore(file.path(path$adam, "adam-pilot-5.xlsx"), where_sep_sheet = FALSE, quiet = TRUE)

adlbc_spec <- metacore %>%
  select_dataset("ADLBC")

# Formats -----------------------------------------------------------------
## map parameter code and parameter
format_paramn <- function(x) {
  dplyr::case_when(
    x == "SODIUM" ~ 18,
    x == "K" ~ 19,
    x == "CL" ~ 20,
    x == "BILI" ~ 21,
    x == "ALP" ~ 22,
    x == "GGT" ~ 23,
    x == "ALT" ~ 24,
    x == "AST" ~ 25,
    x == "BUN" ~ 26,
    x == "CREAT" ~ 27,
    x == "URATE" ~ 28,
    x == "PHOS" ~ 29,
    x == "CA" ~ 30,
    x == "GLUC" ~ 31,
    x == "PROT" ~ 32,
    x == "ALB" ~ 33,
    x == "CHOL" ~ 34,
    x == "CK" ~ 35
  )
}
# Add supplemental information --------------------------------------------
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

# ADSL information --------------------------------------------------------

adsl <- adsl %>%
  select(
    STUDYID, SUBJID, USUBJID, TRT01PN, TRT01P, TRT01AN, TRT01A, TRTSDT, TRTEDT, AGE, AGEGR1, AGEGR1N, RACE, RACEN, SEX,
    COMP24FL, DSRAEFL, SAFFL
  )



adlb01 <- adlb00 %>%
  left_join(adsl, by = c("STUDYID", "USUBJID"))

# Dates -------------------------------------------------------------------

adlb02 <- adlb01 %>%
  derive_vars_dt(
    new_vars_prefix = "A",
    dtc = LBDTC,
    highest_imputation = "n"
  ) %>%
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ADT))



# AVAL(C) -----------------------------------------------------------------
# No imputations are done for values below LL or above UL

adlb03 <- adlb02 %>%
  mutate(
    AVAL = LBSTRESN,
    AVALC = ifelse(!is.na(AVAL), LBSTRESC, NA)
  )

# Parameter ---------------------------------------------------------------

adlb04 <- adlb03 %>%
  mutate(
    PARAM = paste0(LBTEST, " (", LBSTRESU, ")"),
    PARAMCD = LBTESTCD,
    PARAMN = format_paramn(LBTESTCD),
    PARCAT1 = "CHEM" # changed to match prod dataset
  )

# Baseline ----------------------------------------------------------------
## updating to use admiral programming


adlb05 <- adlb04 %>%
  mutate(ABLFL = LBBLFL) %>%
  derive_var_base(
    by_vars = exprs(STUDYID, USUBJID, PARAMCD),
    source_var = AVAL,
    new_var = BASE
  ) %>%
  derive_var_chg() %>%
  mutate(CHG = ifelse(VISITNUM == 1, NA, CHG))


# VISITS ------------------------------------------------------------------

eot <- adlb05 %>%
  filter(ENDPOINT == "Y" | VISITNUM == 12) %>%
  mutate(
    AVISIT = "End of Treatment",
    AVISITN = 99,
    AENTMTFL = "Y"
  )


adlb06 <- adlb05 %>%
  filter(
    grepl("WEEK", VISIT, fixed = TRUE) |
      grepl("UNSCHEDULED", VISIT, fixed = TRUE) |
      grepl("SCREENING", VISIT, fixed = TRUE)
  ) %>% # added conditions to include screening and unscheduled visits
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

# Limits ------------------------------------------------------------------

# updating to use admiral dataset
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

# Derive ANL01FL
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
  full_join(adlb08, by = c("USUBJID", "PARAMCD", "LBSEQ"), multiple = "all") %>%
  ungroup()

# Treatment Vars ------------------------------------------------------------
## ADLBC Production data
adlbc <- adlb09 %>%
  mutate(
    TRTP = TRT01P,
    TRTPN = TRT01PN,
    TRTA = TRT01A,
    TRTAN = TRT01AN
  ) %>%
  drop_unspec_vars(adlbc_spec) %>%
  mutate_if(is.character, ~ replace_na(., "")) %>%
  order_cols(adlbc_spec) %>%
  set_variable_labels(adlbc_spec)

### Update format.sas attribute
attr(adlbc$ADT, "format.sas") <- "DATE9"
attr(adlbc$TRTEDT, "format.sas") <- "DATE9"
attr(adlbc$TRTSDT, "format.sas") <- "DATE9"

# saving the dataset as RDS format
saveRDS(adlbc, file.path(path$adam, "adlbc.rds"))
