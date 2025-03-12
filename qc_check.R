args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Please provide exactly two directory paths as arguments.")
}

dir1 <- args[1]
dir2 <- args[2]

if (!dir.exists(dir1)) {
  stop(paste("Directory does not exist:", dir1))
}

if (!dir.exists(dir2)) {
  stop(paste("Directory does not exist:", dir2))
}

files1 <- list.files(dir1)
files2 <- list.files(dir2)

common_files <- intersect(files1, files2)
unique_to_dir1 <- setdiff(files1, files2)
unique_to_dir2 <- setdiff(files2, files1)

cat("Files unique to", dir1, ":\n")
print(unique_to_dir1)

cat("Files unique to", dir2, ":\n")
print(unique_to_dir2)

# This is very basic but we can add in json equality once we have the files
cat("Checking common files for equality:\n")
for (file in common_files) {
  file1_path <- file.path(dir1, file)
  file2_path <- file.path(dir2, file)
  
  if (identical(readLines(file1_path), readLines(file2_path))) {
    cat(file, ": Files are identical\n")
  } else {
    cat(file, ": Files differ\n")
  }
}