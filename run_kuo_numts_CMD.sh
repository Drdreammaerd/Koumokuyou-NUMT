#!/bin/bash
###################################
# Purpose: Run the Kuo Method 3 NUMT pipeline (Direct Execution).
# Author: Yung-Chun Wang <yung-chun@wustl.edu>
# AI Assistant: Gemini Pro
# Modifier: 
# Language: Bash
# Version: 1.7
# Comment: Fixed Step D to match original logic (fix-protein-strand + merge).
# Last Modified Date: 2026-02-04
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

## 2. Smart Execution Function
Execute() {
    local cmd="$1"
    local check_file="${2:-}" # Optional 2nd argument

    # 1. RESUME CHECK: If file exists and size > 0, skip.
    if [[ -n "$check_file" ]] && [[ -s "$check_file" ]] && [[ "$dry_run" == "false" ]]; then
        echo "[SKIP] Output already exists: $check_file"
        return
    fi

    # 2. RUN OR DRY-RUN
    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] $cmd"
    else
        echo "[RUNNING] $cmd"
        eval "$cmd"
    fi
}

## 3. Setup Directory
if [[ "$dry_run" == "false" ]]; then
    mkdir -p "$out_dir"
    echo "Working Directory: $out_dir"
    cd "$out_dir"
else
    echo "[DRY-RUN] mkdir -p $out_dir && cd $out_dir"
fi

# Define the CLEAN nuclear file path
NUCLEAR_ONLY="$out_dir/${name}_no_chrM.fa"

# --- [Step 0] Preprocessing: Remove chrM (GZIP AWARE) ---
echo "--- Step 0: Filtering out chrM from input ---"
if [[ "$input_fasta" =~ \.gz$ ]]; then
    cmd="zcat $input_fasta | awk 'BEGIN{p=1} /^>chrM/ {p=0} /^>chr[0-9XY]/ {p=1} p==1' > $NUCLEAR_ONLY"
else
    cmd="awk 'BEGIN{p=1} /^>chrM/ {p=0} /^>chr[0-9XY]/ {p=1} p==1' $input_fasta > $NUCLEAR_ONLY"
fi
Execute "$cmd" "$NUCLEAR_ONLY"

# --- [Step A] DNA-DNA Alignment ---
echo "--- Step A: DNA-DNA Alignment ---"
Execute "lastdb --circular -c mitogenodb $MITO_DNA" "mitogenodb.prj"
Execute "last-train -S0 --pid=70 --sample-number=0 -P8 mitogenodb $NUCLEAR_ONLY > nu2mitogeno.train" "nu2mitogeno.train"
Execute "lastal -P8 -H1 -J1 -R00 -p nu2mitogeno.train mitogenodb $NUCLEAR_ONLY > nu2mitogeno.maf" "nu2mitogeno.maf"

# --- [Step B] DNA-Protein Alignment ---
echo "--- Step B: DNA-Protein Alignment ---"
Execute "lastdb -q -c mitoprodb $MITO_PROT" "mitoprodb.prj"
Execute "last-train --codon --pid=70 --sample-number=0 -P8 mitoprodb $NUCLEAR_ONLY > nu2mitopro.train" "nu2mitopro.train"
Execute "lastal -P8 -H1 -K1 -m500 -p nu2mitopro.train mitoprodb $NUCLEAR_ONLY > nu2mitopro.maf" "nu2mitopro.maf"

# --- [Step C] Filtering rRNA ---
echo "--- Step C: Filtering rRNA ---"
Execute "maf-Bed nu2mitogeno.maf > nu2mitogeno.bed" "nu2mitogeno.bed"
Execute "maf-Bed nu2mitopro.maf > nu2mitopro.bed" "nu2mitopro.bed"
Execute "remvrrna nu2mitogeno.bed $RRNA_BED > nu2mitogeno_movrrna.bed" "nu2mitogeno_movrrna.bed"
Execute "remvrrna nu2mitopro.bed $RRNA_BED > nu2mitopro_movrrna.bed" "nu2mitopro_movrrna.bed"

# --- [Step D] Merging & Strand Fix ---
echo "--- Step D: Merging Results ---"
# 1. Map Mito-Genome to Mito-Protein (Used for Strand Fix)
Execute "lastdb -P8 -q -c mitoprodb $MITO_PROT" "mitoprodb.prj"
# Note: Using original flags (-D1e10) as requested
Execute "last-train -P8 --codon mitoprodb $MITO_DNA > mtgeno2pro.train" "mtgeno2pro.train"
Execute "lastal -P8 -D1e10 -p mtgeno2pro.train mitoprodb $MITO_DNA > mtgeno2pro.maf" "mtgeno2pro.maf"

# 2. Fix Protein Strand
Execute "fix-protein-strand mtgeno2pro.maf nu2mitopro_movrrna.bed > nu2mitopro_movrrna_fix.bed" "nu2mitopro_movrrna_fix.bed"

# 3. Final Merge
# The 'merge' command usually takes: merge <DNA_BED> <PROTEIN_BED> <OUTPUT_PREFIX>
# It appends ".bed" automatically.
output_prefix="final_numts_${name}"
final_file="${output_prefix}_Numts_filtered.bed"

Execute "merge nu2mitogeno_movrrna.bed nu2mitopro_movrrna_fix.bed $output_prefix" "$final_file"

# Cleanup Temp Fasta
if [[ "$dry_run" == "false" ]]; then
    if [[ -s "$final_file" ]]; then
        rm "$NUCLEAR_ONLY"
        echo "Removed temporary fasta: $NUCLEAR_ONLY"
    else
        echo "WARNING: Final output missing ($final_file), keeping temp fasta for debugging."
    fi
fi

echo "Pipeline completed. Output: $out_dir/$final_file"