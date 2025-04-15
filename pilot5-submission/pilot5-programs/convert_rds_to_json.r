
# Load Libraries ----------------------------------------------------------

library(datasetjson)
library(metacore)
library(dplyr)
library(tidyr)

# Metadata ----------------------------------------------------------------

spec_path <- list.files(path = path$adam, pattern = "adam-pilot-5.xlsx", full.names = T)

specs <- spec_path %>%
  metacore::spec_to_metacore(where_sep_sheet = FALSE)

# Input Files -------------------------------------------------------------

rds_files <- list.files(path = path$adam, patter = "*.rds", full.names = F)

# Pull all required information -------------------------------------------

for (rds_file in rds_files) {
  
  df <- readRDS(file.path(path$adam, rds_file))
  
  df_name <- sub('\\.rds$', '', rds_file)

  df_spec <- specs %>%
    select_dataset(toupper(df_name))

  OIDcols <- df_spec$ds_vars %>%
    dplyr::select(dataset, variable, key_seq) %>%
    dplyr::left_join(df_spec$var_spec, by = c("variable")) %>%
    dplyr::rename(name = variable, dataType = type, keySequence = key_seq, displayFormat = format) %>%
    dplyr::mutate(itemOID = paste0("IT.", dataset, ".", name)) %>%
    dplyr::select(itemOID, name, label, dataType, length, keySequence, displayFormat) %>%
    dplyr::mutate(dataType = 
                    dplyr::case_when(
                      displayFormat == "DATE9." ~ "date",
                      displayFormat == "DATETIME20." ~ "datetime",
                      substr(name, nchar(name)-3+1, nchar(name)) == "DTC" & length == "8" ~ "date",
                      substr(name, nchar(name)-3+1, nchar(name)) == "DTC" & length == "20"  ~ "datetime",
                      dataType == "text" ~ "string",
                      .default = as.character(dataType)
                    ),
                  targetDataType =
                    dplyr::case_when(
                      displayFormat == "DATE9." ~ "integer",
                      displayFormat == "DATETIME20." ~ "integer",
                      .default = NA
                    )
                  
                  ) %>%
    data.frame()
  
  dataset_json(df, 
               
               last_modified = strftime(as.POSIXlt(Sys.time(), "UTC"), "%Y-%m-%dT%H:%M"),
               originator = "R Submission Pilot 5",
               sys = paste0("R on ", R.Version()$os, " ",unname(Sys.info())[[2]]),
               sys_version = R.Version()$version.string,
               version = "1.1.0",
               
               study = "Pilot 5",
               metadata_version = "MDV.TDF_ADaM.ADaM-IG.1.1", # from define
               metadata_ref = file.path(path$adam, "define.xml"),
               
               item_oid = paste0("IG.", toupper(df_name)),
               name = toupper(df_name), 
               dataset_label = df_spec$ds_spec[["label"]], 
               file_oid = file.path(path$adam, df_name),
               columns = OIDcols
               
               ) %>%
    
    write_dataset_json(file = file.path(path$adam_json, paste0(df_name, ".json")))
}

