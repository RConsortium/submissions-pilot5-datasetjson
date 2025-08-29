#!/usr/bin/env python3
"""
This script takes four inputs – a PDF file, a text (.out) file, and two RTF files –
converts the .out and RTF files into PDFs, and then merges them into a single output PDF.

Usage:
    python merge_to_pdf.py kmplot.pdf demographic.out efficacy.rtf primary.rtf merged_output.pdf
"""

import sys
import os
import subprocess
from PyPDF2 import PdfMerger
from fpdf import FPDF

def convert_text_to_pdf(text_file, pdf_out_name):
    """Convert a plain text (.out) file into a PDF using fpdf."""
    try:
        with open(text_file, "r", encoding="utf-8") as f:
            text = f.read()
    except Exception as e:
        print(f"Error reading {text_file}: {e}")
        sys.exit(1)
    
    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.set_font("Arial", size=12)

    # Write each line of the text file into the PDF.
    for line in text.splitlines():
        # Remove or replace characters not supported by the font
        safe_line = line.encode("latin-1", errors="replace").decode("latin-1")
        pdf.cell(0, 10, txt=safe_line, ln=1)
    
    try:
        pdf.output(pdf_out_name)
    except Exception as e:
        print(f"Error creating {pdf_out_name}: {e}")
        sys.exit(1)

def convert_rtf_to_pdf(rtf_file, pdf_out_name):
    """Convert an RTF file to PDF using unoconv."""
    cmd = ["unoconv", "-f", "pdf", "-o", pdf_out_name, rtf_file]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error converting {rtf_file} to PDF with unoconv: {e}")
        sys.exit(1)

def merge_pdfs(pdf_files, output_pdf):
    """Merge multiple PDFs into one using PyPDF2."""
    merger = PdfMerger()
    for pdf in pdf_files:
        try:
            merger.append(pdf)
        except Exception as e:
            print(f"Error appending {pdf}: {e}")
            sys.exit(1)
    try:
        merger.write(output_pdf)
        merger.close()
    except Exception as e:
        print(f"Error writing merged PDF to {output_pdf}: {e}")
        sys.exit(1)

def main():
    # Check for exactly five command-line arguments.
    # argv: [script, kmplot.pdf, demographic.out, efficacy.rtf, primary.rtf, merged_output.pdf]
    if len(sys.argv) != 6:
        print("Usage: {} kmplot.pdf demographic.out efficacy.rtf primary.rtf merged_output.pdf".format(sys.argv[0]))
        sys.exit(1)
    
    # Assign input file paths to variables.
    kmplot_pdf = sys.argv[1]
    demographic_out = sys.argv[2]
    efficacy_rtf = sys.argv[3]
    primary_rtf = sys.argv[4]
    output_pdf = sys.argv[5]

    # Temporary PDFs for the converted out and rtf files.
    temp_demographic_pdf = "temp_demographic.pdf"
    temp_efficacy_pdf = "temp_efficacy.pdf"
    temp_primary_pdf = "temp_primary.pdf"

    print("Converting text (.out) file to PDF...")
    convert_text_to_pdf(demographic_out, temp_demographic_pdf)
    
    print("Converting first RTF file to PDF...")
    convert_rtf_to_pdf(efficacy_rtf, temp_efficacy_pdf)
    
    print("Converting second RTF file to PDF...")
    convert_rtf_to_pdf(primary_rtf, temp_primary_pdf)
    
    print("Merging PDFs...")
    # Merge in this order:
    # 1. kmplot PDF file
    # 2. demographic (.out) converted to PDF
    # 3. efficacy RTF converted to PDF
    # 4. primary RTF converted to PDF
    pdf_list = [kmplot_pdf, temp_demographic_pdf, temp_efficacy_pdf, temp_primary_pdf]
    
    merge_pdfs(pdf_list, output_pdf)
    
    # Remove temporary files.
    os.remove(temp_demographic_pdf)
    os.remove(temp_efficacy_pdf)
    os.remove(temp_primary_pdf)
    
    print("Merging complete. Output file:", output_pdf)

if __name__ == "__main__":
    main()
