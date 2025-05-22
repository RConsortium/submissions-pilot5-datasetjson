# Load necessary library
library(haven)

# Specify the source and destination directories
source_dir <- "/cloud/project/original-sdtmdata"
destination_dir <- "/cloud/project/pilot5-submission/pilot5-input"

# Create destination directory if it doesn't exist
if (!dir.exists(destination_dir)) {
  dir.create(destination_dir, recursive = TRUE)
}

# List all XPT files in the source directory
xpt_files <- list.files(source_dir, pattern = "\\.xpt$", full.names = TRUE)

# Loop through each XPT file and convert it to RDS
for (xpt_file in xpt_files) {
  # Read the XPT file
  data <- read_xpt(xpt_file)

  # Create an RDS file path
  file_name <- tools::file_path_sans_ext(basename(xpt_file))
  rds_file <- file.path(destination_dir, paste0(file_name, ".rds"))

  # Save as RDS
  saveRDS(data, file = rds_file)

  cat("Converted:", xpt_file, "to", rds_file, "\n")
}
