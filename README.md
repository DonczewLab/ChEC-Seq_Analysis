# CHEC-seq Analysis Snakemake Workflow

![CHEC Analysis](/images/CHECSeq_pipeline.png)  
- OpenAI. (2025). Scientific data visualization: CHEC-seq pipeline schematic [AI-generated image]. DALL-E. Retrieved from ChatGPT interface.

---

## 1) Project Description

**CHEC-seq Analysis Snakemake Workflow** is a Snakemake pipeline designed for Chromatin Endogenous Cleavage (CHEC) experiments. Rather than manually invoking each step (QC, trimming, alignment, coverage generation), this pipeline automates the entire process from **raw FASTQ** inputs to **multiple coverage tracks** (raw, CPM, and spike-in normalized).

### Key Features

- **Flexible Spike-In Normalization**  
  + Simultaneously aligns reads to the primary **S. cerevisiae** genome and a **spike-in** genome (e.g., *D. melanogaster*), calculating a per-sample scaling factor to accurately normalize coverage.

- **Multiple Coverage Outputs**  
  + **Raw** BigWig: unnormalized coverage  
  + **CPM** BigWig: normalized to read depth  
  + **Spike-In** BigWig: additional normalization via spike-in factor

- **Automatic Trimming & QC**  
  + BBDuk handles adapter removal  
  + FastQC runs on both raw and trimmed FASTQs

- **Modular, Parallel Workflow**  
  + Each step defined as a Snakemake rule with explicit inputs/outputs  
  + Snakemake orchestrates HPC job submissions, ensuring only out-of-date steps rerun

---

## 2) Intended Use Case

This pipeline is **ideal** for researchers performing **CHEC-seq** who:

- Start with raw FASTQ reads  
- Use an external spike-in organism (e.g., *D. melanogaster*) for normalization  
- Want to produce coverage files for genome browsers  
- Prefer an automated, HPC-friendly solution

By offering multiple coverage normalizations and easy HPC integration, this pipeline streamlines the data preparation for subsequent analysis or visualization (e.g., IGV tracks, coverage heatmaps).

---

## 3) Dependencies and Configuration

All parameters and module versions are specified in `config/config.yml`

**Key fields include**:
- `scer_genome`: path to the **S. cerevisiae** Bowtie2 index  
- `dmel_genome`: path to the **D. melanogaster** Bowtie2 index (spike-in)  
- `bbmap_ref`: adapter sequence reference for BBDuk  
- `binSize`: bin size for coverage generation  
- `fastqc, bowtie2, samtools, deeptools, bedtools, ucsc, python`: module versions for HPC or conda environments

**Changing Genomes**  
+ If using a different spike-in (e.g. *S. pombe*), just update the relevant Bowtie2 index and references in `config.yml`.

**Tool Versions and Modules**  
+ The `config.yml` file also specifies software versions. You can adapt these if your HPC environment has different versions or you use a conda environment.

---

## 4) Tools & Modules

This Snakemake pipeline relies on:
- **FastQC** for read quality checks  
- **BBDuk** (in **BBMap**) for adapter trimming  
- **Bowtie2** for alignments  
- **Samtools** for BAM conversions/indexing  
- **DeepTools** (bamCoverage) for coverage generation  
- **Bedtools** (optional steps)  
- **Python** for spike-in factor calculations

---

## 5) Example Data

A minimal test dataset can be placed in a `resources/` folder (not included by default). Update `samples.csv` to point to these FASTQs for a quick test run. Once confirmed, replace with your real CHEC-seq data.

---

## 6) Explanation of `samples.csv`

`samples.csv` defines which FASTQ files to process. Each row includes at least:

| sample             | fastq1                        | fastq2                       |
|--------------------|-------------------------------|------------------------------|
| **SampleA**        | /path/to/SampleA_R1.fastq.gz  | /path/to/SampleA_R2.fastq.gz |
| **SampleB**        | /path/to/SampleB_R1.fastq.gz  | /path/to/SampleB_R2.fastq.gz |

+ **sample**: unique sample ID that will serve as file naming convention downstream
+ **fastq1** and **fastq2**: file paths to paired-end reads

---

## 7) Examples of Output

1. **Spike-In Factors**  
- `results/spikein_factors/spikein_factors.csv`

2. **Coverage Tracks**  
- `*_raw.bw` in `results/bigwig/scer/raw/`
- `*_CPM.bw` in `results/bigwig/scer/cpm/`
- `*_SpikeIn.bw` in `results/bigwig/scer/spikein/`

3. **Trimming and QC**  
- FastQC HTML reports in `results/qc/fastqc/`
- Trimmed FASTQs in `results/trimmed/`

---

## 8) Instructions to run on Slurm managed HPC
8A. Clone repository
```
git clone https://github.com/JK-Cobre-Help/CutandTag_Analysis_Snakemake.git
```
8B. Load modules
```
module purge
module load slurm python/3.10 pandas/2.2.3 numpy/1.22.3 matplotlib/3.7.1
```
8C. Modify samples and config file
```
vim samples.csv
vim config.yml
```
8D. Dry Run
```
snakemake -npr
```
8E. Run on HPC with config.yml options
```
sbatch --wrap="snakemake -j 999 --use-envmodules --latency-wait 60 --cluster-config config/cluster_config.yml --cluster 'sbatch -A {cluster.account} -p {cluster.partition} --cpus-per-task {cluster.cpus-per-task}  -t {cluster.time} --mem {cluster.mem} --output {cluster.output}'"
```
