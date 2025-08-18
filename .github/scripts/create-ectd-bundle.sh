#!/usr/bin/env bash
set -euo pipefail # strict mode
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
function l { # Log a message to the terminal.
    echo
    echo -e "[$SCRIPT_NAME] ${1:-}"
}

# Define file and directory paths
ECTD_BUNDLE_DIR=submissions-pilot5-datasetjson-to-fda
ECTD_LETTER_DIR=${ECTD_BUNDLE_DIR}/m1/us
ECTD_ROOT_DIR=${ECTD_BUNDLE_DIR}/m5/datasets/rconsortiumpilot4container/analysis/adam
ECTD_ADAM_DATASETS_DIR=${ECTD_BUNDLE_DIR}/m5/datasets/rconsortiumpilot5/analysis/adam/datasets
ECTD_SDTM_DATASETS_DIR=${ECTD_BUNDLE_DIR}/m5/datasets/rconsortiumpilot5/tabulations/sdtm
ECTD_PROGRAMS_DIR=${ECTD_BUNDLE_DIR}/m5/datasets/rconsortiumpilot5/analysis/adam/programs
ADRG_DESTINATION_DIR=${ECTD_ADAM_DATASETS_DIR}
README_DESTINATION_DIR=${ECTD_BUNDLE_DIR}
LETTER_DESTINATION_DIR=${ECTD_LETTER_DIR}
ADRG_SOURCE_DIR=adrg
ADRG_SOURCE_FILE=adrg-quarto-pdf.pdf
ADRG_DEST_FILE=adrg.pdf
README_SOURCE_DIR=ectd_readme
README_SOURCE_FILE=README.md
README_DEST_FILE=README.md
LETTER_SOURCE_DIR=cover-letter
LETTER_SOURCE_FILE=cover-letter.pdf
LETTER_DEST_FILE=cover-letter.pdf
RENV_SOURCE_FILE=renv.lock
RENV_DEST_FILE=renv-lock.txt
RENV_DESTINATION_DIR=${ECTD_PROGRAMS_DIR}
SDTM_DATASETS_SOURCE_DIR=pilot5-submission/pilot5-input/sdtmdata/datasetjson
SDTM_DATASETS_DESTINATION_DIR=${ECTD_SDTM_DATASETS_DIR}
ADAM_DATASETS_SOURCE_DIR=pilot5-submission/pilot5-output/pilot5-datasetjson
ADAM_DATASETS_DESTINATION_DIR=${ECTD_ADAM_DATASETS_DIR}
PROGRAMS_SOURCE_DIR=pilot5-submission/pilot5-programs
PROGRAMS_DESTINATION_DIR=${ECTD_PROGRAMS_DIR}

# TODO: Verify that the following outputs should be included
OUTPUT_TLF_PDF_DIR=pilot5submission/pilot5-output/pilot5-tlfs/pdf
OUTPUT_TLF_RTF_DIR=pilot5submission/pilot5-output/pilot5-tlfs/rtf
OUTPUT_JSON_DIR=pilot5submission/pilot5-output/pilot5-datasetjson

# Create directory structure for ectd bundle
mkdir -p "${ECTD_LETTER_DIR}"
mkdir -p "${ECTD_PROGRAMS_DIR}"
mkdir -p "${ECTD_ADAM_DATASETS_DIR}"
mkdir -p "${ECTD_SDTM_DATASETS_DIR}"

# Copy ADRG (PDF version)
if [ -f "${ADRG_SOURCE_DIR}/${ADRG_SOURCE_FILE}" ]; then
  echo "Copying ${ADRG_SOURCE_DIR}/${ADRG_SOURCE_FILE}"
  if [ ! -d "$ADRG_DESTINATION_DIR" ]; then
    echo "Create new directory ${ADRG_DESTINATION_DIR}"
    mkdir -p "${ADRG_DESTINATION_DIR}"
  fi
  cp "${ADRG_SOURCE_DIR}/${ADRG_SOURCE_FILE}" "${ADRG_DESTINATION_DIR}/${ADRG_DEST_FILE}"
fi

echo "ADRG copied to ${ADRG_DESTINATION_DIR}/${ADRG_DEST_FILE}"

# TODO: Copy README for ectd repository
# if [ -f "${README_SOURCE_DIR}/${README_SOURCE_FILE}" ]; then
#   echo "Copying ${README_SOURCE_DIR}/${README_SOURCE_FILE}"
#   if [ ! -d "$README_DESTINATION_DIR" ]; then
#     echo "Create new directory ${README_DESTINATION_DIR}"
#     mkdir -p "${README_DESTINATION_DIR}"
#   fi
#   cp "${README_SOURCE_DIR}/${README_SOURCE_FILE}" "${README_DESTINATION_DIR}/${README_DEST_FILE}"
# fi

# echo "README copied to ${README_DESTINATION_DIR}/${README_DEST_FILE}"

# TODO: Copy cover letter (PDF version)
# if [ -f "${LETTER_SOURCE_DIR}/${LETTER_SOURCE_FILE}" ]; then
#   echo "Copying ${LETTER_SOURCE_DIR}/${LETTER_SOURCE_FILE}"
#   if [ ! -d "$LETTER_DESTINATION_DIR" ]; then
#     echo "Create new directory ${LETTER_DESTINATION_DIR}"
#     mkdir -p "${LETTER_DESTINATION_DIR}"
#   fi
#   cp "${LETTER_SOURCE_DIR}/${LETTER_SOURCE_FILE}" "${LETTER_DESTINATION_DIR}/${LETTER_DEST_FILE}"
# fi

# echo "Cover letter copied to ${LETTER_DESTINATION_DIR}/${LETTER_DEST_FILE}"

# Rename renv.lock to renv-lock.txt and copy to ECTD
if [ -f "${RENV_SOURCE_FILE}" ]; then
  echo "Copying ${RENV_SOURCE_FILE}"
  if [ ! -d "$RENV_DESTINATION_DIR" ]; then
    echo "Create new directory ${RENV_DESTINATION_DIR}"
    mkdir -p "${RENV_DESTINATION_DIR}"
  fi
  cp "${RENV_SOURCE_FILE}" "${RENV_DESTINATION_DIR}/${RENV_DEST_FILE}"
fi

# Copy input SDTM data sets in rds format to ECTD SDTM datasets directory
if [ -d "$SDTM_DATASETS_SOURCE_DIR" ]; then
  echo "Copying json data files from ${SDTM_DATASETS_SOURCE_DIR}"
  for file in "${SDTM_DATASETS_SOURCE_DIR}"/*.json; do
    if [ -f "${file}" ]; then
      cp "$file" "${SDTM_DATASETS_DESTINATION_DIR}/."
    fi
  done
fi

# Copy input ADAM data sets in json format to ECTD ADAM datasets directory
if [ -d "$ADAM_DATASETS_SOURCE_DIR" ]; then
  echo "Copying json data files from ${ADAM_DATASETS_SOURCE_DIR}"
  for file in "${ADAM_DATASETS_SOURCE_DIR}"/*.json; do
    if [ -f "${file}" ]; then
      cp "$file" "${ADAM_DATASETS_DESTINATION_DIR}/."
    fi
  done
fi

# Copy R programs to ECTD programs directory
# - Only dataset creation and tlf programs
if [ -d "$PROGRAMS_SOURCE_DIR" ]; then
  echo "Copying R programs from ${PROGRAMS_SOURCE_DIR}"
  if [ ! -d "$PROGRAMS_DESTINATION_DIR" ]; then
    echo "Create new directory ${PROGRAMS_DESTINATION_DIR}"
    mkdir -p "${PROGRAMS_DESTINATION_DIR}"
  fi

  # dataset programs
  for file in "${PROGRAMS_SOURCE_DIR}"/ad*.r; do
    if [ -f "${file}" ]; then
      cp "$file" "${PROGRAMS_DESTINATION_DIR}/."
    fi
  done

  # tlf programs
  for file in "${PROGRAMS_SOURCE_DIR}"/tlf*.r; do
    if [ -f "${file}" ]; then
      cp "$file" "${PROGRAMS_DESTINATION_DIR}/."
    fi
  done

  # helper program
  if [-f "${PROGRAMS_SOURCE_DIR}/pilot5-helper-fcns.r" ]; then
    cp "${PROGRAMS_SOURCE_DIR}/pilot5-helper-fcns.r" "${PROGRAMS_DESTINATION_DIR}/."
  fi
fi 


