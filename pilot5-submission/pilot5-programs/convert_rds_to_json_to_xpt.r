# Load required libraries
library(datasetjson)
library(haven)
library(stringr)
library(dplyr)

source("pilot5-submission/pilot5-programs/convert_rds_to_json.r")

# Specify the folder containing the JSON files.
# Change the path below to your folder.
folder_path <- "pilot5-submission/pilot5-output/pilot5-datasetjson"

# Create a list of all .json files in the folder.
json_files <- list.files(path = folder_path, pattern = "\\.json$", full.names = TRUE)


# Check if any JSON files were found:
if (length(json_files) == 0) {
  message("No JSON files found in ", folder_path)
} else {
  # Loop over each file: read the JSON and write as .xpt
  for (file in json_files) {
    # Read the JSON file.
    # Ensure your JSON file structure is a table (list of records or JSON array) that converts to a data.frame.
    data <- read_dataset_json(file, decimals_as_floats = TRUE)

    # Optionally, coerce to a data.frame if necessary:
    if (!is.data.frame(data)) {
      data <- as.data.frame(data)
    }
    if ("VISITNUM" %in% names(data)) {
      # Check if any VISITNUM values have more than two digits after the decimal point.
      # Here we convert the numbers to characters with full precision so we can check the pattern.
      has_extra_digits <- grepl("\\.[0-9]{3,}$", as.character(data$VISITNUM))

      if (any(has_extra_digits)) {
        message("Some VISITNUM values have more than two digits after the decimal; cleaning those values.")

        # Process those values: format them so that trailing zeros are removed.
        # The format() call with 'trim=TRUE' suppresses unnecessary trailing zeros.
        data <- data %>%
          mutate(VISITNUM = ifelse(has_extra_digits,
            as.numeric(format(VISITNUM, trim = TRUE, scientific = FALSE)),
            VISITNUM
          ))
      } else {
        message("VISITNUM is present and does not have extra digits.")
      }
    } else {
      message("VISITNUM column is not present in the dataset.")
    }

    # Construct the output file name by replacing .json with .xpt
    out_file <- sub("\\.json$", ".xpt", file)

    # Write the data frame to an xpt file
    write_xpt(data, out_file, version = 5)

    # Print a message for successful conversion
    message("Converted: ", file, " -> ", out_file)
  }
}
