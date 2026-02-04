# ============================================================
#   Last Alignment Tool (https://gitlab.com/mcfrith/last)
#   Updated: 2026-01-28
#
#   Builds:
#   - Linux (amd64): docker buildx build --platform linux/amd64 -t dreammaerd/last-train:v4 --load .
#
#   Example Run:
#   - Local: docker run -it --rm --platform linux/amd64 -v $(pwd):/data dreammaerd/last-train:v4 /bin/bash
# ============================================================
FROM ubuntu:20.04

LABEL org.opencontainers.image.authors="David Wang <yung-chun@wustl.edu>"
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    python-is-python3 \
    zlib1g-dev \
    locales \
    bedtools \
    wget \
    gawk \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure Locale
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.utf8 \
    && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8

WORKDIR /opt

# 3. Install LAST
RUN git clone https://gitlab.com/mcfrith/last.git && \
    cd last && \
    sed -i 's/-msse4//g' src/makefile && \
    make && \
    make install && \
    cd .. && rm -rf last

# 4. Install seg-suite
RUN git clone https://github.com/mcfrith/seg-suite.git && \
    cd seg-suite && \
    make && \
    cp last-pair-probs /usr/local/bin/ || true && \
    cp bin/* /usr/local/bin/ && \
    cd .. && rm -rf seg-suite

# 5. Install Koumokuyou/NUMTs Scripts (Original repo)
RUN git clone https://github.com/Koumokuyou/NUMTs.git && \
    chmod +x NUMTs/bin/* && \
    cp NUMTs/bin/* /usr/local/bin/ && \
    rm -rf NUMTs

# =======================================================
# 6. Install CUSTOM Script and References (NEW SECTION)
# =======================================================

# A. Create a directory for reference files
RUN mkdir -p /opt/ref

# B. Copy the reference files from your local 'Kou_NUMT' folder to the container
COPY ref/chrM.fa \
     ref/hg38_rRNA.bed \
     ref/mito_proteins.fa \
     /opt/ref/

# C. Copy the custom script to /usr/local/bin so it is executable from anywhere
COPY run_kuo_numts_CMD.sh /usr/local/bin/run_kuo_numts_CMD.sh

# D. Make the script executable
RUN chmod +x /usr/local/bin/run_kuo_numts_CMD.sh

# E. Set the Environment Variable so the script knows where /opt/ref is
ENV NUMT_REF_DIR="/opt/ref"

# =======================================================

# 7. Set Path
ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /data