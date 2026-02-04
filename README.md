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

## Usage

### 1. Pull from Docker Hub
```bash
docker pull dreammaerd/last-train:v4