# Overview

The objectives of the **R Consortium R Submission Pilot 5** Project are:  

1. Deliver a **publicly accessible** R-based Submission through the [eCTD portal](https://www.fda.gov/drugs/electronic-regulatory-submission-and-review/electronic-common-technical-document-ectd) using datasetjson.
1. Expand on the work done in [Submission Pilot 1 and Pilot 3](https://rconsortium.github.io/submissions-pilot1/), by now utilizing R to generate ADaM datasets.


**NOTE:** This is a FDA-industry collaboration through the non-profit organization [R Consortium](https://www.r-consortium.org/).


## Important Links

* Repository with ECTD materials: <https://github.com/RConsortium/submissions-pilot5-datasetjson-to-fda>
* Preview version of the Analysis Data Reviewer Guide (ADRG):
    * HTML Format: <https://rpodcast.quarto.pub/pilot-5-aanalysis-data-reviewers-guide/>
    * PDF Format: <https://rsubmission-draft.us-east-1.linodeobjects.com/pilot5-adrg-quarto-pdf.pdf>

---

## Repository Guide

This section provides a brief description of every file and folder in this repository, grouped by their overall purpose.

---

### Project Configuration

These root-level files control the R project environment and reproducibility settings.

| File | Purpose |
|------|---------|
| `project.Rproj` | RStudio project file; sets the working directory and project-level IDE settings. |
| `.Rprofile` | Executed automatically on R startup. Activates `renv`, sets the file download method, and defines a `path` list that all analysis programs use to locate input/output directories. |
| `renv.lock` | Package dependency lockfile managed by `renv`. Records the exact version of every R package used, enabling reproducible installs via `renv::restore()`. |
| `renv/` | `renv` infrastructure folder (auto-generated). Contains the `activate.R` bootstrap script and the project-local package library. |
| `.renvignore` | Tells `renv` which files or folders to ignore when scanning for package dependencies. |
| `.lintr` | Configuration for the `lintr` R linting tool, defining code-style rules applied by the lint CI workflow. |
| `default.nix` | [Nix](https://nixos.org/) environment specification that pins R, all R packages, system libraries, and LaTeX packages to exact versions. Used by CI to create a fully reproducible build environment. |
| `build_nixconfig.R` | R script that calls `rix::rix()` to regenerate `default.nix` from a human-readable list of R packages and system dependencies. Run this whenever the package list needs updating. |

---

### Original Source Data

These folders hold the raw, unmodified input datasets received from external sources (e.g., from Pilot 1/3). They are read-only reference copies and are not modified by any program.

| Folder | Purpose |
|--------|---------|
| `original-sdtmdata/` | Original SDTM datasets in XPT (SAS transport) format, together with the define.xml, define.pdf, blank CRF, and a Pinnacle 21 validation report. These are the source tabulation datasets before any conversion. |
| `original-adamdata/` | Original ADaM datasets in XPT format from Pilot 1/3. Used as the reference ("gold standard") comparator when QC-checking the Pilot 5 ADaM datasets. |

---

### Pilot 5 Submission Materials (`pilot5-submission/`)

This folder contains all programs, input data, and output data that form the actual submission package.

#### Input Data (`pilot5-submission/pilot5-input/`)

| Folder | Purpose |
|--------|---------|
| `pilot5-input/adamdata/` | ADaM datasets in RDS format (R's native binary format) used as inputs to the ADaM programs. Also contains `adam-pilot-5.xlsx`, the ADaM specifications workbook used by `metacore`/`xportr` for metadata. |
| `pilot5-input/sdtmdata/datasetjson/` | SDTM datasets in Dataset-JSON format (`.json`), together with `define.xml` and associated stylesheet. These are the submission-ready SDTM tabulation files that the ADaM programs read via `read_dataset_json()`. |

#### ADaM Dataset Programs (`pilot5-submission/pilot5-programs/`)

Five R programs generate the ADaM datasets from SDTM Dataset-JSON inputs. Each program reads the relevant SDTM domains, derives required variables following ADaM conventions using the `admiral` package, and writes out a Dataset-JSON file.

| Program | Purpose |
|---------|---------|
| `adsl.r` | Generates **ADSL** (Subject-Level Analysis Dataset). Derives demographic, baseline, and treatment variables from DM, DS, EX, QS, SV, VS, SC, and MH domains. |
| `adae.r` | Generates **ADAE** (Adverse Events Analysis Dataset). Derives adverse event variables and flags from AE and ADSL. |
| `adlbc.r` | Generates **ADLBC** (Laboratory Data – Chemistry Analysis Dataset). Derives lab chemistry variables and baseline values from LB and ADSL. |
| `adtte.r` | Generates **ADTTE** (Time-to-Event Analysis Dataset). Derives time-to-event variables (e.g., time to dropout) from DS and ADSL. |
| `adadas.r` | Generates **ADADAS** (ADAS-Cog Analysis Dataset). Derives cognitive assessment scores from QS and ADSL. |

#### TLF (Tables, Listings, and Figures) Programs (`pilot5-submission/pilot5-programs/`)

Four R programs generate the submission outputs (tables, listings, and figures). Each reads the relevant ADaM Dataset-JSON files and produces RTF, PDF, and/or plain-text output files.

| Program | Purpose |
|---------|---------|
| `tlf-demographic.r` | Produces **Table 14-2.01** – Summary of Demographic and Baseline Characteristics, using the `rtables` package. Output: `.out` (plain text). |
| `tlf-efficacy.r` | Produces **Table 14-3.01** – Primary Efficacy Analysis (ADAS-Cog change from baseline), using the `Tplyr` package. Output: `.rtf`. |
| `tlf-kmplot.r` | Produces **Figure 14-1** – Kaplan-Meier plot of time-to-dropout, using `ggplot2` and `ggsurvfit`. Output: `.pdf`. |
| `tlf-primary.r` | Produces **Table 14-3.02** – ANCOVA Primary Efficacy Summary, using the `Tplyr` package. Output: `.rtf`. |

#### Data Conversion Utilities (`pilot5-submission/pilot5-programs/`)

Several helper scripts handle format conversion between XPT, RDS, and Dataset-JSON.

| Program | Purpose |
|---------|---------|
| `convert_xpt_to_rds.r` | Reads SDTM XPT files from `original-sdtmdata/` and saves them as RDS files for easier handling in R. |
| `convert_xpt_to_datasetjson.r` | Reads XPT files and converts them to Dataset-JSON format, extracting variable metadata (type, length, label) to produce spec-compliant JSON. |
| `convert_rds_to_json.r` | Reads ADaM RDS files and writes them as Dataset-JSON, using `metacore` specs from `adam-pilot-5.xlsx` for metadata. |
| `convert_rds_to_xpt.r` | Reads ADaM RDS files and writes them as XPT files (SAS transport format) for cross-format compatibility. |
| `convert_rds_to_json_to_xpt.r` | Pipeline script that calls `convert_rds_to_json.r` first and then converts the resulting JSON files back to XPT. |
| `pilot5-helper-fcns.r` | Shared helper functions used across ADaM and TLF programs, including `nest_rowlabels()` for Tplyr table formatting and `format_sitegr1()` for pooled site grouping. |
| `run-all-adams-tlfs.r` | Orchestration script that sequentially sources all five ADaM programs and all four TLF programs using `purrr::walk()`, with error handling. |

#### Combined Report (`pilot5-submission/pilot5-programs/`)

| File | Purpose |
|------|---------|
| `pilot5-cmb-report-manual.qmd` | Quarto document that assembles all four TLF outputs (demographic table, efficacy table, KM plot, and primary table) into a single combined PDF report for submission. |
| `pilot5-cmb-report-manual.pdf` | Pre-rendered PDF of the combined TLF report, included in the eCTD bundle. |
| `cmb-report-manual-files/` | Supporting PDF files for individual TLFs embedded in the combined report. |

#### Output Data (`pilot5-submission/pilot5-output/`)

| Folder | Purpose |
|--------|---------|
| `pilot5-output/pilot5-datasetjson/` | Pilot 5 ADaM datasets in Dataset-JSON format (`.json`) and XPT format (`.xpt`), plus `define.xml` and associated stylesheet. These are the primary submission deliverables. |
| `pilot5-output/pilot5-tlfs/` | Pilot 5 TLF outputs (`.out`, `.rtf`, `.pdf`) organized into `out/`, `rtf/`, and `pdf/` sub-folders. |
| `pilot5-output/pilot3-adams/` | Pilot 3 ADaM datasets in XPT format. Used as the reference comparator in the QC dataset check. |
| `pilot5-output/pilot3-tlfs/` | Pilot 3 TLF outputs in `out/`, `rtf/`, and `pdf/` sub-folders. Used as the reference comparator in the TLF QC check. |

---

### QC and Validation

Two Quarto documents implement automated quality control by comparing Pilot 5 outputs to their Pilot 3 equivalents.

| File | Purpose |
|------|---------|
| `qcReport.qmd` | **Dataset QC Report.** Loads each Pilot 5 ADaM RDS file and the corresponding Pilot 3 XPT file, then uses `diffdf` to compare them variable-by-variable. Writes a summary to `qc.Rmd` (posted as a PR comment) and creates a `qc.fail` sentinel file if any differences are found. |
| `tlf-qc.qmd` | **TLF QC Report.** Compares Pilot 5 and Pilot 3 TLFs: `.out` files are compared as plain text using `waldo::compare()`; PDF and RTF outputs are converted to images and evaluated by an Anthropic Claude LLM via the `ellmer` package for visual similarity scoring. Creates a `qc-tlf.fail` sentinel file on failures. |

---

### Analysis Data Reviewer's Guide (`adrg/`)

This folder contains all materials for authoring and publishing the ADRG, including an LLM-assisted pipeline for auto-generating sections.

#### ADRG Source and Renderers

| File | Purpose |
|------|---------|
| `adrg/_adrg.qmd` | Main ADRG content written in Quarto Markdown. Included by both renderers below. Contains the full narrative (introduction, dataset descriptions, derivation details, appendices, etc.). |
| `adrg/adrg-quarto-html.qmd` | Renders `_adrg.qmd` as a self-contained **HTML** file with a table of contents and [Hypothes.is](https://web.hypothes.is/) annotation support, published to Quarto Pub. |
| `adrg/adrg-quarto-pdf.qmd` | Renders `_adrg.qmd` as a **PDF** using the DejaVu Mono font (via Nix/LaTeX) for submission. Uploaded to object storage as `pilot5-adrg-quarto-pdf.pdf`. |
| `adrg/_publish.yml` | Quarto publishing configuration that maps `adrg-quarto-html.qmd` to its Quarto Pub deployment ID. |
| `adrg/figures/` | Static figures (images, diagrams) embedded in the ADRG document. |

#### LLM Pipeline for ADRG Auto-Generation (`adrg/llm-adrg-utils/`)

These scripts implement an automated pipeline that uses a Large Language Model (LLM) to extract structured information from TLF programs and populate ADRG sections (e.g., variable listings, filter criteria, output names).

| File | Purpose |
|------|---------|
| `llm_pipeline.qmd` | Orchestration notebook for the full LLM pipeline. Reads all TLF R programs, sends structured prompts to the LLM to extract variables/datasets/filter criteria, and writes the results to CSV files in `llm-adrg-out/`. |
| `llm_api.R` | Provider-agnostic LLM API wrapper built on `ellmer`. Supports OpenAI, Anthropic, DeepSeek, Gemini, Groq, Azure, Bedrock, and others. Provides a single `call_llm()` function used throughout the pipeline. |
| `llm_prompts.R` | Defines the natural-language prompt strings sent to the LLM for each extraction task (variable/dataset extraction, filter criteria, output filename, comparison/QC). |
| `util.R` | Utility function (`convert_to_dataframe()`) that parses the LLM's CSV-formatted text response into an R data frame. |
| `logging.R` | Logging utilities that write every LLM prompt and response to a dated log file in `logs/`, supporting audit trails for LLM-generated content. |

#### LLM Pipeline Outputs (`adrg/llm-adrg-out/`)

CSV files produced by the LLM pipeline, used to populate tables in the ADRG.

| File | Purpose |
|------|---------|
| `adam_var_label_table.csv` | LLM-extracted table of ADaM variable names and their labels, sourced from the TLF programs. |
| `tlg_var_filter_table.csv` | LLM-extracted table of filter criteria applied in each TLF program, formatted for the ADRG analysis summary section. |
| `pkg_descriptions.csv` | Descriptions of R packages used in the submission programs, for inclusion in the ADRG software inventory. |
| `R_Packages_and_Versions.csv` | Full list of R packages and their versions from the project environment, for inclusion in the ADRG appendix. |

---

### eCTD Package Materials

These folders and files are used to build and publish the eCTD (electronic Common Technical Document) submission bundle.

#### Cover Letter (`cover-letter/`)

| File | Purpose |
|------|---------|
| `cover-letter/cover-letter.qmd` | Quarto source for the formal FDA submission cover letter, using the `letter-typst` format with R Consortium branding. |
| `cover-letter/cover-letter.pdf` | Pre-rendered PDF of the cover letter, included in the eCTD bundle under `m1/us/`. |
| `cover-letter/rconsortium.png` | R Consortium logo used in the cover letter header. |
| `cover-letter/_extensions/` | Quarto extension(s) required to render the Typst letter format. |

#### eCTD README (`ectd_readme/`)

| File | Purpose |
|------|---------|
| `ectd_readme/README.qmd` | Quarto source for the README published to the [eCTD submission repository](https://github.com/RConsortium/submissions-pilot5-datasetjson-to-fda). Rendered to GitHub-Flavored Markdown and describes the eCTD folder structure and submission contents. |

---

### GitHub Actions (CI/CD) (`.github/`)

Automated workflows that run on pushes and pull requests to ensure code quality, validate outputs, and publish deliverables.

#### Workflows (`.github/workflows/`)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `lint.yml` | Push / PR to `main` | Runs `lintr` on all R programs in `pilot5-submission/pilot5-programs/` to enforce code style. Fails the build if any lint errors are detected. |
| `style.yml` | PR to `main` | Runs `styler` on R programs in dry-run mode to detect formatting inconsistencies. |
| `spelling.yml` | PR to `main` | Runs `spelling::spell_check_files()` on all R and Rmd files to catch spelling errors. |
| `qc.yaml` | PR to `main` | Renders `qcReport.qmd` to compare Pilot 5 ADaM datasets against Pilot 3 reference datasets using `diffdf`. Posts a summary comment on the PR and fails the job if differences are found. |
| `tlf-qc.yaml` | PR to `main` | Renders `tlf-qc.qmd` to compare Pilot 5 TLF outputs against Pilot 3 outputs using text diff and LLM-based visual comparison. Posts a summary comment and fails if mismatches exceed threshold. |
| `publish-adrg.yaml` | Push to `main` (ADRG changes) | Builds the Nix environment and renders the ADRG as both HTML (published to Quarto Pub) and PDF (uploaded to Linode object storage). |
| `publish-ectd-bundle.yaml` | Push to `main` (key file changes) | Builds the full eCTD bundle: renders ADRG, README, and cover letter; copies all submission files to the [eCTD repository](https://github.com/RConsortium/submissions-pilot5-datasetjson-to-fda); and pushes the updated bundle. |

#### Scripts (`.github/scripts/`)

| Script | Purpose |
|--------|---------|
| `create-ectd-bundle.sh` | Bash script that assembles the eCTD submission folder structure by copying ADaM/SDTM JSON files, R programs, the ADRG PDF, the cover letter, `renv.lock`, the combined report, and the eCTD README into the correct ICH eCTD module directories. |
| `push-ectd-bundle.sh` | Bash script that commits and pushes the assembled eCTD bundle to the `submissions-pilot5-datasetjson-to-fda` repository. |
| `create-cmb-report.py` | Python script that converts `.out` (plain text) and `.rtf` TLF files to PDF using `fpdf` and `unoconv`/LibreOffice, then merges them with the KM-plot PDF into a single combined report PDF using `PyPDF2`. |

---

### Logs (`logs/`)

| File | Purpose |
|------|---------|
| `logs/llm_calls_<date>.log` | Daily log files written by `logging.R` that record every LLM prompt, model name, and response during the ADRG pipeline. Provides an audit trail for AI-generated content. |
