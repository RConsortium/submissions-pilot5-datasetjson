#' Gather variable metadata in Dataset JSON compliant format
#'
#' @param n Variable name
#' @param .data Dataset to gather attributes
#'
#' @returns Columns compliant data frame
extract_xpt_meta <- function(n, .data) {
  attrs <- attributes(.data[[n]])

  out <- list()

  # Identify the variable type
  if (inherits(.data[[n]], "Date")) {
    out$dataType <- "date"
    out$targetDataType <- "integer"
  } else if (inherits(.data[[n]], "POSIXt")) {
    out$dataType <- "datetime"
    out$targetDataType <- "integer"
  } else if (inherits(.data[[n]], "numeric")) {
    if (any(is.double(.data[[n]]))) {
      out$dataType <- "float"
    } else {
      out$dataType <- "integer"
    }
  } else if (inherits(.data[[n]], "hms")) {
    out$dataType <- "time"
    out$targetDataType <- "integer"
  } else {
    out$dataType <- "string"
    out$length <- max(purrr::map_int(.data[[n]], nchar), 1L)
  }

  out$itemOID <- n
  out$name <- n
  out$label <- attr(.data[[n]], "label")
  out$displayFormat <- attr(.data[[n]], "format.sas")
  tibble::as_tibble(out)
}

#' Extract variable metadata from an XPT file in Dataset JSON format
#'
#' @param xpt_path Path to the XPT file
#' @param item_oid Item OID (usually dataset name)
#' @param dataset_name Name of dataset
#' @param write_json Logical: write JSON to file?
#' @param output_dir Directory to write output files (if write_json = TRUE)
#'
#' @return A list with meta info and json content (and file path, if written)
#'
#' @examples
#' \dontrun{
#' process_xpt_to_json(
#'   file.path(system.file(package = "datasetjson"), "adsl.xpt"),
#'   output_dir = file.path("pilot5-submission", "pilot5-input", "sdtmdata")
#' )
#' }
process_xpt_to_json <- function(xpt_path,
                                item_oid = NULL,
                                dataset_name = NULL,
                                write_json = TRUE,
                                names_labels = extract_names_labels("original-sdtmdata/define.xml"),
                                output_dir = ".") {
  print(xpt_path)
  dataset <- haven::read_xpt(xpt_path)
  item_oid <- item_oid %||% tolower(tools::file_path_sans_ext(basename(xpt_path)))
  dataset_name <- dataset_name %||% item_oid
  # set dataset label if not already set
  if (is.null(attr(dataset, "label"))) {
    label <- names_labels |>
      dplyr::filter(OID == dataset_name) |>
      dplyr::pull(Label)
    attr(dataset, "label") <- label
  }

  dataset_meta <- purrr::map_df(names(dataset), extract_xpt_meta,
    .data =
      dataset
  )
  ds_json <- datasetjson::dataset_json(
    dataset,
    item_oid = item_oid,
    name = dataset_name,
    dataset_label = attr(dataset, "label"),
    columns = dataset_meta
  )
  json_file_content <- datasetjson::write_dataset_json(ds_json, 
                                                       float_as_decimals = TRUE
                                                       )

  results <- list(meta = dataset_meta, json_content = json_file_content)

  if (write_json) {
    out_file <- file.path(output_dir, paste0(item_oid, ".json"))
    writeLines(json_file_content, out_file)
  }
}


#' Extract Name and def:Label from ItemGroupDef nodes in a define.xml file
#'
#' This function parses a CDISC SDTM define.xml file and extracts the OID and def:Label
#' attributes from all ItemGroupDef nodes as a tidy tibble.
#'
#' @param xml_path Path to the define.xml file.
#'
#' @return A tibble with columns \code{OID} and \code{Label} for each ItemGroupDef.
#' @export
#'
#' @examples
#' \dontrun{
#' result <- extract_names_labels("original-sdtmdata/define.xml")
#' print(result)
#' }
extract_names_labels <- function(xml_path) {
  doc <- xml2::read_xml(xml_path)
  ns <- xml2::xml_ns(doc)
  itemgroup_nodes <- xml2::xml_find_all(doc, ".//d1:ItemGroupDef", ns)
  purrr::map(
    itemgroup_nodes,
    ~ tibble::tibble(
      OID = xml2::xml_attr(.x, "OID"),
      Label = xml2::xml_attr(.x, "Label")
    )
  ) |>
    purrr::list_rbind()
}

list.files("original-sdtmdata/",
  pattern = "\\.xpt$",
  full.names = TRUE
) |>
  purrr::discard(~ stringr::str_detect(.x, "(ts)\\.xpt$")) |>
  purrr::walk(
    process_xpt_to_json,
    output_dir = file.path(
      "pilot5-submission",
      "pilot5-input",
      "sdtmdata",
      "datasetjson"
    )
  )
