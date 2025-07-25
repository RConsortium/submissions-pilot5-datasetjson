if (Sys.getenv("CI") != "true") source("renv/activate.R")
Sys.setenv(RENV_DOWNLOAD_FILE_METHOD = "libcurl")


# File locations ----------------------------------------------------------

path <- list(
  sdtm = file.path(getwd(), "pilot5-submission/pilot5-input/sdtmdata/datasetjson"),
  adam = file.path(getwd(), "pilot5-submission/pilot5-input/adamdata"),
  output = file.path(getwd(), "pilot5-submission/pilot5-output/pilot5-tlfs"),
  adam_json = file.path(getwd(), "pilot5-submission/pilot5-output/pilot5-datasetjson"),
  programs = file.path(getwd(), "pilot5-submission/pilot5-programs")
)
