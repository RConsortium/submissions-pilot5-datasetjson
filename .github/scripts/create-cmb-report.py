#!/usr/bin/env python3
"""
This script takes three files – a PDF file, a .out file (text), and an RTF file –
converts the .out and RTF files into PDFs, and then merges them into a single output PDF.

Usage:
    python merge_to_pdf.py input.pdf file.out file.rtf output.pdf
"""

import sys
import os
import subprocess
from PyPDF2 import PdfMerger
from fpdf import FPDF

def convert_text_to_pdf(text_file, pdf_out_name):
    """Convert a plain text (.out) file into a PDF using fpdf."""
    try:
        with open(text_file, "r") as f:
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
        pdf.cell(0, 10, txt=line, ln=1)
    
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
    # Check that there are exactly four arguments
    if len(sys.argv) != 5:
        print("Usage: {} input.pdf file.out file.rtf output.pdf".format(sys.argv[0]))
        sys.exit(1)
    
    input_pdf = sys.argv[1]
    text_file = sys.argv[2]
    rtf_file = sys.argv[3]
    output_pdf = sys.argv[4]

    # Temporary PDF files for the converted .out and RTF files.
    temp_text_pdf = "temp_text.pdf"
    temp_rtf_pdf = "temp_rtf.pdf"

    print("Converting text file to PDF...")
    convert_text_to_pdf(text_file, temp_text_pdf)
    
    print("Converting RTF file to PDF...")
    convert_rtf_to_pdf(rtf_file, temp_rtf_pdf)
    
    print("Merging PDFs...")
    pdf_list = [input_pdf, temp_text_pdf, temp_rtf_pdf]
    merge_pdfs(pdf_list, output_pdf)
    
    # Clean up temporary files.
    os.remove(temp_text_pdf)
    os.remove(temp_rtf_pdf)
    
    print("Merging complete. Output file:", output_pdf)

if __name__ == "__main__":
    main()
