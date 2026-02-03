#!/bin/bash
###################################
# Purpose: Run the Kuo Method 3 NUMT pipeline (Direct Execution).
# Author: Yung-Chun Wang <yung-chun@wustl.edu>
# AI Assistant: Gemini Pro
# Modifier: 
# Language: Bash
# Version: 1.4
# Comment: Step 0 uses user-defined awk for chrM removal.
# Last Modified Date: 2026-02-03
###################################

## Date
DATE=$( date +%F | sed "s/-//g")

### Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

## Help function
Help() {
	echo ""
	echo "To run the Kuo Method 3 NUMT pipeline directly."
	echo "Syntax: $0 [-i|o|n|d|h]"
	echo "-i     Full path to input Fasta (Can include chrM; script will filter it)."
	echo "-o     Full path for the output directory."
	echo "-n     Sample Name (Used for final output naming)."
	echo "-d     Dry run mode."
	echo "-h     Print this Help."
	echo ""
}

## Options
input_fasta=""
out_dir=""
name=""
dry_run="false"

while getopts "i:o:n:dh" option; do
	case $option in
		i) input_fasta=$OPTARG ;;
		o) out_dir=$OPTARG ;;
		n) name=$OPTARG ;;
		d) dry_run="true" ;;
		h) Help; exit ;;
		\?) echo "Error: Invalid option"; Help; exit 1 ;;
	esac
done

if [[ -z "$input_fasta" ]] || [[ -z "$out_dir" ]] || [[ -z "$name" ]]; then
	echo "Error: Missing required arguments."
	Help; exit 1
fi

## 1. Define Paths
REF_DIR="${NUMT_REF_DIR:-/opt/ref}"
MITO_DNA="$REF_DIR/chrM.fa"
MITO_PROT="$REF_DIR/mito_proteins.fa"
RRNA_BED="$REF_DIR/hg38_rRNA.bed"

Execute() {
    local cmd="$1"
    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] $cmd"
    else
        echo "[RUNNING] $cmd"
        eval "$cmd"
    fi
}

## 2. Setup Directory
if [[ "$dry_run" == "false" ]]; then
    mkdir -p "$out_dir"
    echo "Working Directory: $out_dir"
    cd "$out_dir"
else
    echo "[DRY-RUN] mkdir -p $out_dir && cd $out_dir"
fi

# Define the CLEAN nuclear file path
NUCLEAR_ONLY="$out_dir/${name}_no_chrM.fa"

# --- [Step 0] Preprocessing: Remove chrM ---
echo "--- Step 0: Filtering out chrM from input ---"

# Using YOUR specific awk command
# Note: This logic assumes headers are >chr1, >chr2... or >chrM. 
Execute "awk 'BEGIN{p=1} /^>chrM/ {p=0} /^>chr[0-9XY]/ {p=1} p==1' $input_fasta > $NUCLEAR_ONLY"

# --- [Step A] DNA-DNA Alignment ---
echo "--- Step A: DNA-DNA Alignment ---"
Execute "lastdb --circular -c mitogenodb $MITO_DNA"
Execute "last-train -S0 --pid=70 --sample-number=0 -P8 mitogenodb $NUCLEAR_ONLY > nu2mitogeno.train"
Execute "lastal -P8 -H1 -J1 -R00 -p nu2mitogeno.train mitogenodb $NUCLEAR_ONLY > nu2mitogeno.maf"

# --- [Step B] DNA-Protein Alignment ---
echo "--- Step B: DNA-Protein Alignment ---"
Execute "lastdb -q -c mitoprodb $MITO_PROT"
Execute "last-train --codon --pid=70 --sample-number=0 -P8 mitoprodb $NUCLEAR_ONLY > nu2mitopro.train"
Execute "lastal -P8 -H1 -K1 -m500 -p nu2mitopro.train mitoprodb $NUCLEAR_ONLY > nu2mitopro.maf"

# --- [Step C] Filtering rRNA ---
echo "--- Step C: Filtering rRNA ---"
Execute "maf-Bed nu2mitogeno.maf > nu2mitogeno.bed"
Execute "maf-Bed nu2mitopro.maf > nu2mitopro.bed"
Execute "remvrrna nu2mitogeno.bed $RRNA_BED > nu2mitogeno_movrrna.bed"
Execute "remvrrna nu2mitopro.bed $RRNA_BED > nu2mitopro_movrrna.bed"

# --- [Step D] Merging ---
echo "--- Step D: Merging Results ---"
Execute "lastdb -P8 -q -c mitoprodb $MITO_PROT"
Execute "last-train --codon --pid=70 --sample-number=0 -P8 mitoprodb $MITO_DNA > mito2mitopro.train"
Execute "lastal -P8 -H1 -K1 -m10 -p mito2mitopro.train mitoprodb $MITO_DNA > mito2mitopro.maf"
Execute "maf-Bed mito2mitopro.maf > mito2mitopro.bed"

final_output="final_numts_${name}.bed"
Execute "numt-filter -n nu2mitogeno_movrrna.bed -p nu2mitopro_movrrna.bed -m mito2mitopro.bed > $final_output"

# Cleanup Temp Fasta
if [[ "$dry_run" == "false" ]]; then
    rm "$NUCLEAR_ONLY"
    echo "Removed temporary fasta: $NUCLEAR_ONLY"
fi

echo "Pipeline completed. Output: $out_dir/$final_output"