# Koumokuyou-NUMT

A containerized implementation of the "Koumokuyou" method for Nuclear Mitochondrial DNA (NUMT) detection, utilizing LAST alignment. This pipeline facilitates the identification of NUMT insertion sites by filtering standard nuclear-mitochondrial alignments.

## Original References
This pipeline implements the method described in:
* **Paper**: [Wei et al., 2025 (BioRxiv)](https://www.biorxiv.org/content/10.1101/2025.03.14.643190v2.full)
* **Original Code**: [Koumokuyou/NUMTs GitHub](https://github.com/Koumokuyou/NUMTs/tree/main)

## Features
* **Self-Contained**: Includes all dependencies (LAST, bedtools, custom scripts).
* **Reproducible**: Dockerized environment ensures consistent results across compute clusters.
* **Streamlined**: Includes preprocessing scripts to handle reference formatting.

## Installation

### Option 1: Pull from Docker Hub
```bash
docker pull dreammaerd/last-train:v4
```

### Option 2: Build Locally
```bash
git clone https://github.com/Drdreammaerd/Koumokuyou-NUMT.git
cd Koumokuyou-NUMT
docker build -t <your_custom_image_name> .
```

## Usage

To run the pipeline, you must use the `-v` flag to mount your local data folder into the container (usually mapped to `/data`).

### Basic Syntax
```bash
docker run --rm \
    -v /path/to/your/data:/data \
    <your_image_name> \
    run_kuo_numts_CMD.sh -i /data/input.fa -o /data/output_dir -n SampleName
```

> **Note**: Replace `<your_image_name>` with `dreammaerd/last-train:v4` (if pulled from Docker Hub) or your custom name (if built locally).

### Arguments
| Argument | Description |
|----------|-------------|
| `-v /local/path:/data` | Maps your computer's folder to `/data` inside the container. |
| `-i` | Path to input FASTA (Must start with `/data/...`). |
| `-o` | Output directory (Must start with `/data/...`). |
| `-n` | Sample name (used for file prefixes). |

## Example Execution

Assuming your input file is named `genome.fa` and is located in your current directory:

```bash
# 1. Create an output folder
mkdir -p results

# 2. Run the pipeline
docker run --rm -v $(pwd):/data <your_image_name> \
    run_kuo_numts_CMD.sh \
    -i /data/genome.fa \
    -o /data/results \
    -n MySample
```

## 🛠 Pipeline Workflow

The `run_kuo_numts_CMD.sh` script performs the following steps automatically:

1. **Reference Loading**: Loads internal chrM and mitochondrial protein references from `/opt/ref`.
2. **Preprocessing**: Filters chrM from the input nuclear genome to prevent self-alignment.
3. **Alignment (LAST)**:
    - **DNA-DNA**: Aligns nuclear DNA to mitochondrial DNA.
    - **DNA-Protein**: Aligns nuclear DNA to mitochondrial proteins (for higher sensitivity).
4. **Filtering**: Removes rRNA regions and low-confidence alignments.
5. **Merging**: Combines DNA and Protein alignment evidence into a final BED file.

## 📂 Repository Structure

- **Dockerfile**: Recipe for building the environment.
- **run_kuo_numts_CMD.sh**: Main execution script.
- **ref/**: Directory containing mitochondrial reference files (`chrM.fa`, `mito_proteins.fa`, `hg38_rRNA.bed`).