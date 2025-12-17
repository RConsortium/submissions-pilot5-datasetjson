#' Nest Row Labels in a Tplyr table
#'
#' This is a (high ungeneralized) helper function. Current function assumes that
#' row_label1 groups row_label2, and turns row_label1 into a stub over its
#' related groups of row_label2.
#'
#' @param .dat Input data set - should come from a built Tplyr table.
#'
#' @importFrom dplyr distinct rename bind_rows mutate select arrange across
#' @importFrom dplyr starts_with
#' @importFrom tidyr replace_na
#'
#' @return data.frame with row labels nested
#' @export
nest_rowlabels <- function(.dat) {
  stubs <- .dat %>%
    distinct(row_label1, ord_layer_index) %>%
    rename(row_label = row_label1) %>%
    mutate(
      ord_layer_1 = 0,
      ord_layer_2 = 0
    )

  .dat %>%
    select(-row_label1, row_label = row_label2) %>%
    bind_rows(stubs) %>%
    arrange(ord_layer_index, ord_layer_1, ord_layer_2) %>%
    mutate(
      across(starts_with("var"), ~ tidyr::replace_na(., ""))
    )
}

#' Derive pooled site group
#'
#' `format_sitegr1` derives the `SITEGR1` variable, which pools sites with fewer than 3 subjects in any one treatment group.
#'
#' @param x The input vector of values to format
#'
#' @export
format_sitegr1 <- function(x) {
  case_when(
    x %in% c("702", "706", "707", "711", "714", "715", "717") ~ "900",
    TRUE ~ x
  )
}

#' ANCOVA Model data processing necessary for Table 14-3.01
#'
#' This function handles the necessary data processing to handle the CDISC pilot
#' primary endpoint analysis. The original source can be found
#' [here](https://github.com/atorus-research/CDISC_pilot_replication/blob/3c8e9e3798c02be8d93bd8e8944d1e0d3f6519e2/programs/funcs.R#L401)
#'
#' @importFrom tidyr pivot_longer
#' @importFrom glue glue
#'
#' @param data Source dataset (filtered by flags)
#' @param var Variable on which model should be run
#' @param wk Visit to be modeled
#'
#' @return Formatted dataframe
#' @export

efficacy_models <- function(data, var = NULL, wk = NULL) {
  # Need to set contrasts to work for Type III SS. See analysis results metadata for
  # table 14-3.01. Reference for R here: https://www.r-bloggers.com/anova-%E2%80%93-type-iiiiii-ss-explained/
  op <- options(contrasts = c("contr.sum", "contr.poly"))

  # Subset to analyze
  data <- data %>%
    filter(AVISITN == wk)

  data <- data %>%
    mutate(
      TRTPCD = case_when(
        TRTPN == 0 ~ "Pbo",
        TRTPN == 54 ~ "Xan_Lo",
        TRTPN == 81 ~ "Xan_Hi"
      )
    )

  # Create an ordered factor variable for the models
  data["TRTPCD_F"] <- factor(data$TRTPCD, levels = c("Xan_Hi", "Xan_Lo", "Pbo"))
  data["AWEEKC"] <- factor(data$AVISIT)

  # Set up the models
  if (var == "CHG") {
    model1 <- lm(CHG ~ TRTPN + SITEGR1 + BASE, data = data)
    model2 <- lm(CHG ~ TRTPCD_F + SITEGR1 + BASE, data = data)
  } else {
    model1 <- lm(AVAL ~ TRTPN + SITEGR1, data = data)
    model2 <- lm(AVAL ~ TRTPCD_F + SITEGR1, data = data)
  }

  ## Dose Response --- NOTE: For statistics portions, I purposefully did not
  # import the libraries to make it explicitly clear which packages were being
  # used to match P-values.
  ancova <- drop1(model1, . ~ ., test = "F")

  # Pull it out into a table
  sect1 <- tibble(
    row_label = c("p-value(Dose Response) [1][2]"),
    `81` = c(num_fmt(ancova[2, "Pr(>F)"], int_len = 4, digits = 3, size = 12))
  ) %>%
    pad_row()

  ## Pairwise Comparisons ----
  # Here's a reference for the emmeans package and how to use it:
  #   https://cran.r-project.org/web/packages/emmeans/vignettes/confidence-intervals.html
  # Adjustments made are in line with the analysis results metadata in the analysis define
  # and PROC GLM documentation.

  # Linear model but use treatment group as a factor now
  # LS Means and weight proportionately to match OM option on PROC GLM in SAS
  lsm <- emmeans::lsmeans(model2, ~TRTPCD_F, weights = "proportional")

  # Here on out - it's all the same data manipulation
  # Get pairwise contrast and remove P-values adjustment for multiple groups
  cntrst_p <- emmeans::contrast(lsm, method = "pairwise", adjust = NULL)
  # 95% CI
  cntrst_ci <- confint(cntrst_p)

  # merge and convert into dataframe
  pw_data <- as_tibble(summary(cntrst_p)) %>%
    merge(as_tibble(cntrst_ci)) %>%
    rowwise() %>%
    # Create the display strings
    mutate(
      p = num_fmt(p.value, int_len = 4, digits = 3, size = 12),
      diff_se = as.character(
        glue("{num_fmt(estimate, int_len=2, digits=1, size=4)} ({num_fmt(SE, int_len=1, digits=2, size=4)})")
      ),
      ci = as.character(
        glue("({num_fmt(lower.CL, int_len=2, digits=1, size=4)};{num_fmt(upper.CL, int_len=1, digits=1, size=3)})")
      )
    ) %>%
    # Clean out the numeric variables
    select(contrast, p, diff_se, ci) %>%
    # Transpose
    pivot_longer(c("p", "diff_se", "ci"), names_to = "row_label")

  # Subset Xan_Lo - Pbo into table variables
  xan_lo <- pw_data %>%
    filter(contrast == "Xan_Lo - Pbo") %>%
    # Rename to the table display variable
    select(`54` = value) %>%
    pad_row()

  # Add in row_label
  xan_lo["row_label"] <- c("p-value(Xan - Placebo) [1][3]", "  Diff of LS Means (SE)", "  95% CI", "")

  # Subset Xan_hi - Pbo into table variables
  xan_hi <- pw_data %>%
    filter(contrast == "Xan_Hi - Pbo") %>%
    # Rename to the table display variable
    select(`81` = value) %>%
    pad_row()
  # Add in row_label
  xan_hi["row_label"] <- c("p-value(Xan - Placebo) [1][3]", "  Diff of LS Means (SE)", "  95% CI", "")
  xan_hi["ord"] <- c(1, 2, 3, 4) # Order for sorting

  # Subset Xan_Hi - Xan_Lo into table variable
  xan_xan <- pw_data %>%
    filter(contrast == "Xan_Hi - Xan_Lo") %>%
    # Rename to the table display variable
    select(`81` = value)
  # Add in row_label
  xan_xan["row_label"] <- c("p-value(Xan High - Xan Low) [1][3]", "  Diff of LS Means (SE)", "  95% CI")
  xan_xan["ord"] <- c(5, 6, 7) # Order for sorting

  # Pack it all together
  pw_final <- merge(xan_lo, xan_hi, by = "row_label") %>%
    bind_rows(xan_xan) %>%
    arrange(ord)

  # Bind and clean up
  bind_rows(sect1, pw_final) %>%
    select(row_label,
      `var1_Xanomeline Low Dose` = `54`,
      `var1_Xanomeline High Dose` = `81`
    )
}

#' Format numeric value
#'
#' @inheritParams base::formatC
#'
#' @examples
#' fmt_num(1.25, digits = 1)
#' @export
fmt_num <- function(x, digits, width = digits + 4) {
  formatC(x,
    digits = digits,
    format = "f",
    width = width
  )
}

#' Format point estimator
#'
#' @param .mean mean of an estimator.
#' @param .sd sd of an estimator.
#' @param digits number of digits for `.mean` and `.sd`.
#'
#' @examples
#' fmt_est(1.25, 0.5)
#' @export
fmt_est <- function(.mean,
                    .sd,
                    digits = c(1, 2)) {
  .mean <- fmt_num(.mean, digits[1], width = digits[1] + 4)
  .sd <- fmt_num(.sd, digits[2], width = digits[2] + 3)
  paste0(.mean, " (", .sd, ")")
}

#' Format confidence interval
#'
#' @param .est an estimator.
#' @param .lower lower confidence interval bound of an estimator.
#' @param .upper upper confidence interval bound of an estimator.
#' @param digits number of digits for `.est`, `.lower`, and `.upper`.
#' @param width the total field width.
#'
#' @examples
#' fmt_ci(1, -0.25, 1.32)
#' @export
fmt_ci <- function(.est,
                   .lower,
                   .upper,
                   digits = 2,
                   width = digits + 3) {
  .est <- fmt_num(.est, digits, width)
  .lower <- fmt_num(.lower, digits, width)
  .upper <- fmt_num(.upper, digits, width)
  paste0(.est, " (", .lower, ",", .upper, ")")
}

#' Format p-Value
#'
#' @param .p a p-value.
#' @param digits number of digits for `.est`, `.lower`, and `.upper`.
#'
#' @examples
#' fmt_pval(0.2)
#' @export
fmt_pval <- function(.p, digits = 3) {
  scale <- 10^(-1 * digits)
  p_scale <- paste0("<", digits)
  ifelse(.p < scale, p_scale, fmt_num(.p, digits = digits))
}

#' Add a padding row below data
#'
#' @param .data Data to pad
#' @param n Number of rows to pad
#'
#' @importFrom stringr str_pad
#'
#' @return Dataframe with extra blank rows
#' @export
pad_row <- function(.data, n = 1) {
  .data[(nrow(.data) + 1):(nrow(.data) + n), ] <- ""
  .data
}

#' Number formatter
#'
#' Format numbers for presentation, with proper rounding of data
#'
#' @param var Variable to format
#' @param digits Desired number of decimal places
#' @param size String size
#' @param int_len Space allotted for integer side of the decimal
#'
#' @return Formatted string
#' @export
num_fmt <- Vectorize(function(var, digits = 0, size = 10, int_len = 3) {
  # Formats summary stat strings to align display correctly

  if (is.na(var)) {
    return("")
  }

  # Set nsmall to input digits
  nsmall <- digits

  # Incremement digits for to compensate for display
  if (digits > 0) {
    digits <- digits + 1
  }

  # Form the string
  return(str_pad(
    format(
      # Round
      round(var, nsmall),
      # Set width of format string
      width = (int_len + digits),
      # Decimals to display
      nsmall = nsmall
    ),
    # Overall width padding
    side = "right", size
  ))
})

#' Write ADaM Dataset to datasetjson Format
#'
#' This function takes an ADaM dataset and its metacore specification and writes
#' it as a datasetjson file with proper metadata.
#'
#' @param df The ADaM dataset (data frame) to write
#' @param df_spec The metacore specification object for the dataset (from select_dataset())
#' @param dataset_name The name of the dataset (e.g., "adsl", "adae")
#' @param output_path The output directory path where the JSON file should be written
#'
#' @return NULL (invisibly). The function writes a JSON file as a side effect.
#' @importFrom datasetjson dataset_json write_dataset_json
#' @importFrom dplyr select left_join rename mutate case_when
#' @export
#'
#' @examples
#' \dontrun{
#' # Load metacore specs
#' metacore <- spec_to_metacore("adam-pilot-5.xlsx", where_sep_sheet = FALSE, quiet = TRUE)
#' adsl_spec <- metacore %>% select_dataset("ADSL")
#' 
#' # Write dataset to JSON
#' write_dataset_json_with_metadata(adsl, adsl_spec, "adsl", path$adam_json)
#' }
write_dataset_json_with_metadata <- function(df, df_spec, dataset_name, output_path) {
  # Prepare column metadata for JSON
  oid_cols <- df_spec$ds_vars %>%
    select(dataset, variable, key_seq) %>%
    left_join(df_spec$var_spec, by = c("variable")) %>%
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
  dataset_json(df,
    last_modified = strftime(as.POSIXlt(Sys.time(), "UTC"), "%Y-%m-%dT%H:%M"),
    originator = "R Submission Pilot 5",
    sys = paste0("R on ", R.Version()$os, " ", unname(Sys.info())[[2]]),
    sys_version = R.Version()$version.string,
    version = "1.1.0",
    study = "Pilot 5",
    metadata_version = "MDV.TDF_ADaM.ADaM-IG.1.1",
    metadata_ref = file.path(path$adam, "define.xml"),
    item_oid = paste0("IG.", toupper(dataset_name)),
    name = toupper(dataset_name),
    dataset_label = df_spec$ds_spec[["label"]],
    file_oid = file.path(path$adam, dataset_name),
    columns = oid_cols
  ) %>%
    write_dataset_json(file = file.path(output_path, paste0(dataset_name, ".json")), float_as_decimals = TRUE)
  
  invisible(NULL)
}

#' Convert JSON Dataset Files to RDS and Return RDS File Names
#'
#' @description
#' **DEPRECATED**: This function is deprecated. Programs should read directly from 
#' JSON files using `datasetjson::read_dataset_json()` instead of converting to RDS first.
#' 
#' This function takes a character vector of `.json` file paths,
#' reads each with `datasetjson::read_dataset_json()`, saves them as `.rds` files
#' in the specified output directory (or the same location as the input files if not specified),
#' and returns a character vector of the new `.rds` file paths.
#'
#' @param files A character vector of `.json` file paths to convert.
#' @param output_dir Optional. Directory to save the `.rds` files. If NULL, saves alongside the input files.
#' @return A character vector of the new `.rds` file paths.
#' @importFrom purrr walk2
#' @importFrom datasetjson read_dataset_json
#' @export
#'
#' @examples
#' \dontrun{
#' # DEPRECATED - Do not use this approach
#' # Instead, read JSON files directly:
#' # data <- datasetjson::read_dataset_json("file.json", decimals_as_floats = TRUE)
#' 
#' # Old approach (deprecated):
#' sdtm_files <- list.files(
#'   path = "pilot5-submission/pilot5-input/sdtmdata",
#'   pattern = "\\.json$",
#'   full.names = TRUE
#' )
#' adam_files <- list.files(
#'   path = "pilot5-submission/pilot5-input/adamdata",
#'   pattern = "\\.json$",
#'   full.names = TRUE
#' )
#' rds_files <- convert_json_to_rds(c(sdtm_files, adam_files), output_dir = "pilot5-submission/pilot5-output")
#' }
convert_json_to_rds <- function(files, output_dir = NULL) {
  .Deprecated(
    msg = paste(
      "convert_json_to_rds() is deprecated.",
      "Please read JSON files directly using datasetjson::read_dataset_json() instead."
    )
  )
  if (!is.null(output_dir)) {
    # Ensure the output directory exists
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
    rds_files <- file.path(
      output_dir,
      sub("\\.json$", ".rds", tolower(basename(files)))
    )
  } else {
    rds_files <- sub("\\.json$", ".rds", files)
  }
  purrr::walk2(files, rds_files, function(json, rds) {
    datasetjson::read_dataset_json(json, decimals_as_floats = TRUE) |>
      saveRDS(file = rds)
  })
  return(rds_files)
}
