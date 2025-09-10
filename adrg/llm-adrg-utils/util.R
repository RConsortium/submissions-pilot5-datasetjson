convert_to_dataframe <- function(csv_string) {
  # Remove the markdown part and get the actual CSV content
  csv_data <- gsub("^.*?\n", "", csv_string)
  csv_data <- gsub("\n```", "", csv_data)
  csv_data <- gsub("Variable,Dataset\n", "", csv_data) # LLM are not generating column names consistently. some w/ column names and some not. will remove all

  # Read the CSV data into a data frame
  df <- read.csv(text = csv_data, header = FALSE, row.names = NULL)

  return(df)
}
