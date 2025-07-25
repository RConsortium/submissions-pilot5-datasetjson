#' Convert JSON Dataset Files to RDS and Return RDS File Names
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

sdtm_files <- list.files(
  path = "pilot5-submission/pilot5-input/sdtmdata/datasetjson",
  pattern = "\\.json$",
  full.names = TRUE
)

convert_json_to_rds(sdtm_files, output_dir = "pilot5-submission/pilot5-input/sdtmdata/datasetjson")
