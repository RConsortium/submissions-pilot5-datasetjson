#!/usr/bin/env python3

import subprocess
import os
import sys
import shutil
from pathlib import Path

def check_unoconv_installed():
    if shutil.which("unoconv") is None:
        print("Error: 'unoconv' is not installed. Please install unoconv and LibreOffice.")
        sys.exit(1)

def convert_rtf_to_pdf(rtf_path):
    pdf_path = rtf_path.with_suffix('.pdf')
    cmd = ["unoconv", "-f", "pdf", "-o", str(pdf_path), str(rtf_path)]
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"Converted {rtf_path} -> {pdf_path}")
        return pdf_path
    except subprocess.CalledProcessError as e:
        print(f"Error converting {rtf_path}: {e.stderr.decode()}")
        return None

def main():
    check_unoconv_installed()
    rtf_files = list(Path('.').glob('**/*.rtf'))
    if not rtf_files:
        print("No RTF files found.")
        sys.exit(0)
    pdf_paths = []
    for rtf in rtf_files:
        pdf = convert_rtf_to_pdf(rtf)
        if pdf:
            pdf_paths.append(pdf)
    # Stage and commit the new PDFs
    if pdf_paths:
        pdf_relpaths = [str(pdf) for pdf in pdf_paths]
        subprocess.run(["git", "checkout", "-B", "cmb-report-auto"], check=True)
        subprocess.run(["git", "add"] + pdf_relpaths, check=True)
        subprocess.run(["git", "commit", "-m", "Auto-convert RTFs to PDFs"], check=True)
        subprocess.run(["git", "push", "-u", "origin", "cmb-report-auto"], check=True)
        print("Committed and pushed new PDFs to cmb-report-auto branch.")
    else:
        print("No PDFs created.")

if __name__ == "__main__":
    main()