options(repos = c(CRAN = "https://cloud.r-project.org"))

library(here)

json_file <- here("pilot5-submission/pilot5-input/adamdata","adam-pilot-5.json")
excel_file <- here("pilot5-submission/pilot5-input/adamdata","adam-pilot-51.xlsx")

# Load libraries
library(openxlsx)   # read Excel
library(jsonlite)   # write JSON
json_to_excel_multisheet <- function(json_file, excel_file, overwrite = TRUE, auto_width = TRUE) {
  # Read JSON preserving structure
  specs <- fromJSON(json_file, simplifyVector = FALSE)
  
  # If top-level is not named (no keys), place it in a default sheet
  if (is.null(names(specs))) {
    specs <- list(Sheet1 = specs)
  }
  
  wb <- createWorkbook()
  
  # Helper to convert a list-of-rows to data.frame
  rows_to_df <- function(rows) {
    # If a single named list (one row), make it a list of length 1
    if (is.list(rows) && !is.null(names(rows)) && !any(sapply(rows, function(x) is.list(x) || length(x) > 1))) {
      rows <- list(rows)
    }
    # Ensure every element is a list (if not, wrap it)
    rows <- lapply(rows, function(x) if (!is.list(x)) list(value = x) else x)
    if (length(rows) == 0) return(data.frame()) 
    
    # Collect all column names preserving first-seen order
    all_keys <- unique(unlist(lapply(rows, names)))
    
    # Build character matrix: convert atomic scalars to string; nested objects -> JSON string
    mat <- lapply(rows, function(r) {
      vapply(all_keys, function(k) {
        val <- r[[k]]
        if (is.null(val)) return(NA_character_)
        if (is.atomic(val) && length(val) == 1) return(as.character(val))
        # For vectors length > 1 or nested lists, serialize to JSON string
        return(toJSON(val, auto_unbox = TRUE))
      }, FUN.VALUE = character(1), USE.NAMES = FALSE)
    })
    
    mat <- do.call(rbind, mat)
    df <- as.data.frame(mat, stringsAsFactors = FALSE, optional = TRUE)
    names(df) <- all_keys
    
    # Try to convert columns that look numeric/logical to proper types
    df <- as.data.frame(lapply(df, function(col) type.convert(col, as.is = TRUE)), stringsAsFactors = FALSE)
    return(df)
  }
  
  # Loop through domains (sheet names as-is)
  for (sheet in names(specs)) {
    rows <- specs[[sheet]]
    
    # If domain is a single atomic value (e.g., "DM": "something"), wrap into list
    if (!is.list(rows) || (is.atomic(rows) && length(rows) == 1)) {
      rows <- list(rows)
    }
    
    df <- rows_to_df(rows)
    
    # Add a worksheet even if df is empty (keeps sheet present)
    addWorksheet(wb, sheet)
    
    if (ncol(df) == 0 && nrow(df) == 0) {
      # write an empty sheet (or optionally add a note)
      writeData(wb, sheet, data.frame()) 
    } else {
      writeData(wb, sheet, df)
      if (auto_width) setColWidths(wb, sheet, cols = seq_len(ncol(df)), widths = "auto")
    }
  }
  
  saveWorkbook(wb, excel_file, overwrite = overwrite)
  message("✅ Saved Excel: ", excel_file)
}

json_to_excel_multisheet(json_file,excel_file)