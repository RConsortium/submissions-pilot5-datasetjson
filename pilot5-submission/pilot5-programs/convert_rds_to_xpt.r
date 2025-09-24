# Specify the folder containing the .rds files.
# Replace "path/to/your/folder" with the actual directory path.
folder_path <- "pilot5-submission/pilot5-input/adamdata"

# Get a list of all .rds files in the folder (full.names = TRUE returns the full path)
rds_files <- list.files(path = folder_path, pattern = "\\.rds$", full.names = TRUE)

# Loop over each file, read it, and write it as a .xpt file
for (file in rds_files) {
  # Read the RDS file
  data <- readRDS(file)

  # Construct the output file name by replacing the .rds extension with .xpt
  out_file <- sub("\\.rds$", ".xpt", file)

  # Write the data as an xpt file
  write_xpt(data, out_file)

  # Optionally, print a message indicating a successful conversion
  message("Converted: ", file, " -> ", out_file)
}
