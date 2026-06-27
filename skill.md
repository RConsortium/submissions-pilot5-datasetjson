# Skill: Keep README Up to Date

## Purpose

Ensure that `README.md` always accurately reflects every file and folder present in the repository. The README is the primary reference for contributors and reviewers, so it must stay synchronized with the actual repository contents.

## When to Apply This Skill

Apply this skill whenever:

- A new file or folder is added to the repository.
- An existing file or folder is renamed, moved, or removed.
- The purpose of an existing file changes significantly.
- A new GitHub Actions workflow or script is introduced.
- A new program, data folder, or configuration file is created.

## Steps

1. **Audit the repository structure.**
   Walk the full directory tree (excluding `.git/` and `renv/` internals) and list every file and folder. Compare the list against every table and entry in `README.md`.

2. **Identify gaps.**
   Note any file or folder that appears in the repository but is not described in `README.md`, and any entry in `README.md` that refers to a file or folder that no longer exists.

3. **Update `README.md`.**
   - Add a row to the appropriate table for each missing item, following the existing table style (two columns: `File`/`Folder` and `Purpose`).
   - Place the new entry in the correct section. Use the section headings already present in `README.md` as a guide:
     - Project Configuration
     - Original Source Data
     - Pilot 5 Submission Materials (`pilot5-submission/`)
     - QC and Validation
     - Analysis Data Reviewer's Guide (`adrg/`)
     - eCTD Package Materials
     - GitHub Actions (CI/CD) (`.github/`)
     - Logs (`logs/`)
   - Remove or correct any stale entries that refer to deleted or renamed files.
   - Keep descriptions concise and consistent in style with existing entries.

4. **Verify links.**
   Check that every URL and cross-reference in `README.md` (especially in the *Important Links* section) is still valid.

5. **Open a pull request** with the updated `README.md` and a clear commit message such as:
   `docs: sync README with current repository contents`.

## Conventions

- Table column headers are `File` (or `Folder`) and `Purpose`, separated by `|`.
- File and folder names are wrapped in backticks (e.g., `` `example.r` ``).
- Section separators (`---`) appear between major sections.
- Descriptions are written in the present tense (e.g., "Generates ADSL…", "Renders the ADRG…").
- Avoid duplicating information that is already captured in comments within the files themselves; the README entry should give a high-level summary only.
