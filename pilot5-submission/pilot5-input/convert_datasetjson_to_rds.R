#' Convert JSON Dataset Files to RDS and Return RDS File Names
#'
#' This function takes a character vector of `.json` file paths,
#' reads each with `datasetjson::read_dataset_json()`, saves them as `.rds` files
#' in the same location with the same base name, and returns a character vector
#' of the new `.rds` file paths.
#'
#' @param files A character vector of `.json` file paths to convert.
#' @return A character vector of the new `.rds` file paths.
#' @importFrom purrr walk
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
#' rds_files <- convert_json_to_rds(c(sdtm_files, adam_files))
#' }
convert_json_to_rds <- function(files) {
  rds_files <- sub("\\.json$", ".rds", files)
  purrr::walk2(
    files, rds_files,
    function(json, rds) {
      datasetjson::read_dataset_json(json, decimals_as_floats = FALSE) |>
        saveRDS(file = rds)
    }
  )
  return(rds_files)
}

sdtm_files <- list.files(
  path = "pilot5-submission/pilot5-input/sdtmdata",
  pattern = "\\.json$",
  full.names = TRUE
)

adam_files <- list.files(
  path = "pilot5-submission/pilot5-input/adamdata",
  pattern = "\\.json$",
  full.names = TRUE
)

convert_json_to_rds(c(sdtm_files, adam_files))