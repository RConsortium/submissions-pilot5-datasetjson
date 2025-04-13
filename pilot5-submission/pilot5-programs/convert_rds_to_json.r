
# Load Libraries ----------------------------------------------------------

library(datasetjson)
library(metacore)
library(dplyr)
library(tidyr)

# Metadata ----------------------------------------------------------------

spec_path <- list.files(path = path$adam, pattern = "adam-pilot-5.xlsx", full.names = T)

specs <- spec_path %>%
  metacore::spec_to_metacore(where_sep_sheet = FALSE)

sysinfo <- unname(Sys.info()) 

# Input Files -------------------------------------------------------------

rds_files <- list.files(path = path$adam, patter = "*.rds", full.names = F)

# Prep data ---------------------------------------------------------------

for (rds_file in rds_files) {
  
  df <- readRDS(file.path(path$adam, rds_file))
  
  df_name <- sub('\\.rds$', '', rds_file)

  df_spec <- specs %>%
    select_dataset(toupper(df_name))


# Prep CDISC Dataset JSON Specifications - Columns element ----------------

  OIDcols <- df_spec$ds_vars %>%
    dplyr::select(dataset, variable, key_seq) %>%
    dplyr::left_join(df_spec$var_spec, by = c("variable")) %>%
    dplyr::rename(itemOID = dataset, name = variable, dataType = type, keySequence = key_seq) %>%
    dplyr::select(itemOID, name, label, dataType, length, keySequence) %>%
    dplyr::mutate(dataType = 
                    dplyr::case_when(
                      dataType == "text" ~ "string",
                      .default = as.character(dataType)
                    )
                  )

  dataset_json(df, 
               item_oid = "IT.ADTTE",
               name = df_name, 
               dataset_label = df_spec$ds_spec[["label"]], 
               columns = OIDcols,
               file_oid = file.path(path$adam, df_name),
               last_modified = strftime(as.POSIXlt(Sys.time(), "UTC"), "%Y-%m-%dT%H:%M"),
               originator = "R Submission Pilot 5",
               sys = sysinfo[1],
               sys_version = sysinfo[3],
               metadata_version = "MDV.TDF_ADaM.ADaM-IG.1.1", # from define
               metadata_ref = file.path(path$adam, "define.xml"),
               version = "1.1.0") %>%
    write_dataset_json(file = file.path(path$adam_json, paste0(df_name, ".json")))
}
