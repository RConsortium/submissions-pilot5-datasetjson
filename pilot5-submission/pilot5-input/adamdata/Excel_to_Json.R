options(repos = c(CRAN = "https://cloud.r-project.org"))

library(here)

excel_file <- here("pilot5-submission/pilot5-input/adamdata","adam-pilot-5.xlsx")
json_file <- here("pilot5-submission/pilot5-input/adamdata","adam-pilot-5.json")

install.packages("openxlsx")
install.packages("jsonlite")

library(openxlsx)   # for reading Excel
library(jsonlite)   # for writing JSON

excel_to_json_multisheet <- function(excel_file, json_file) {
  # Get all sheet names
  sheet_names <- getSheetNames(excel_file)
  
  # Create a list to hold domain specs
  all_specs <- list()
  
  # Loop through each sheet
  for (sheet in sheet_names) {
    # Read sheet as data frame
    df <- read.xlsx(excel_file, sheet = sheet)
    
    # Convert each row to a list
    df_list <- apply(df, 1, as.list)
    
    # Keep the sheet name exactly as in Excel
    all_specs[[sheet]] <- df_list
  }
  
  # Write to JSON
  write_json(all_specs, json_file, pretty = TRUE, auto_unbox = TRUE)
  
  cat("✅ Conversion complete! JSON saved at:", json_file, "\n")
}

#excel_to_json_multisheet("adam-pilot-5.xlsx", "adam-pilot-5.json")

excel_to_json_multisheet(excel_file,json_file)

