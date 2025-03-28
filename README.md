# ChEC-seq Analysis Snakemake Workflow

![CHEC Analysis](/images/CHECSeq_pipeline.png)  
- OpenAI. (2025). Scientific data visualization: CHEC-seq pipeline schematic [AI-generated image]. DALL-E. Retrieved from ChatGPT interface.

---

## 1) Project Description

**ChEC-seq Analysis Snakemake Workflow** is a Snakemake pipeline designed for Chromatin Endogenous Cleavage (ChEC) experiments. Rather than manually invoking each step (QC, trimming, alignment, coverage generation, mean coverage merging, optional WIG conversion), this pipeline automates the entire process from **raw FASTQ** inputs to **multiple coverage tracks** (raw, CPM, and spike-in normalized), as well as merged replicates to create an average signal track via a `merge_group` column in `samples.csv`.

### Key Features

- **Flexible Spike-In Normalization**  
  + Simultaneously aligns reads to the primary **S. cerevisiae** genome and a **spike-in** genome (e.g., *D. melanogaster*), calculating a per-sample scaling factor to accurately normalize coverage.

- **Automatic Trimming & QC**  
  + BBDuk handles adapter removal  
  + FastQC runs on both raw and trimmed FASTQs

- **Multiple Coverage Outputs**  
  + **Raw** BigWig, BedGrapn, & Wig: unnormalized coverage  
  + **CPM** BigWig, BedGraph, & Wig: normalized to read depth  
  + **Spike-In** BigWig, BedGraph, & Wig: additional normalization via spike-in factor  
  + **Average Coverage** BigWig, BedGraphs & Wig: average signal for single samples and merged sets

- **Merge Coverage by Group**  
  + A `merge_group` column in `samples.csv` allows replicates to be combined into a mean coverage bedGraph and BigWig/WIG

- **Modular, Parallel Workflow**  
  + Each step defined as a Snakemake rule with explicit inputs/outputs  
  + Snakemake manages HPC job submissions, ensuring fast parallel processing of samples and the ability to only rerun needed steps

---

## 2) Intended Use Case

This pipeline is **ideal** for researchers performing **ChEC-seq** who:

- Start with raw FASTQ reads  
- Use an external spike-in organism (e.g., *D. melanogaster*) for normalization   
- Want to produce coverage files for genome browsers (BigWigs or WIGs)  
- Prefer an automated, HPC-friendly solution  
- Need to merge replicates by condition or replicate group

By offering multiple coverage normalizations and easy HPC integration, this pipeline streamlines data preparation for subsequent analysis or visualization (e.g., IGV tracks, coverage heatmaps), including **mean coverage** tracks for replicate sets.

---

## 3) Dependencies and Configuration

All parameters and module versions are specified in `config/config.yml`

**Key fields include**:
- `scer_genome`: path to the **S. cerevisiae** Bowtie2 index  
- `spikein_genome`: path to the **Spike In** Bowtie2 index (e.g., D. melanogaster)  
- `bbmap_ref`: adapter sequence reference for BBDuk  
- `binSize`: bin size for coverage generation  
- `fastqc, bowtie2, samtools, deeptools, bedtools, ucsc, python`: module versions for HPC

**Changing Genomes**  
+ If using a different spike-in (e.g. *S. pombe*), just update the relevant Bowtie2 index and references in `config.yml`.

**Tool Versions and Modules**  
+ The `config.yml` file specifies all software and specific versions

---

## 4) Tools & Modules

This Snakemake pipeline relies on:
- **FastQC** for read quality checks  
- **BBDuk** (in **BBMap**) for adapter trimming  
- **Bowtie2** for alignments  
- **Samtools** for BAM conversions/indexing  
- **DeepTools** (bamCoverage) for coverage generation  
- **Bedtools** for Average Signal files
- **Python** for spike-in factor calculations and WIG conversions
- **UCSC** (bedGraphToBigWig) to generate BigWigs from bedGraphs

---

## 5) Example Data

A minimal test dataset can be placed in a `resources/` folder (not included currently). Update `samples.csv` to point to these FASTQs for a quick test run. Once confirmed, replace with your real CHEC-seq data.

---

## 6) Explanation of `samples.csv`

`samples.csv` defines which FASTQ files to process. Each row includes at least:

| sample             | fastq1                        | fastq2                       | merge_group |
|--------------------|-------------------------------|------------------------------|-------------|
| **RDY226_DMSO_A**  | /path/ExampleA_R1.fastq.gz    | /path/ExampleA_R2.fastq.gz   | DMSO        |
| **RDY226_DMSO_B**  | /path/ExampleB_R1.fastq.gz    | /path/ExampleB_R2.fastq.gz   | DMSO        |
| **RDY226_IAA_A**   | /path/ExampleC_R1.fastq.gz    | /path/ExampleC_R2.fastq.gz   | IAA         |

+ **sample**: unique sample ID that will serve as file naming convention downstream  
+ **fastq1** and **fastq2**: file paths to paired-end reads  
+ **merge_group**: optional label for merging coverage across replicates (e.g., DMSO vs. IAA). Samples with the same `merge_group` will be averaged into a mean coverage bedGraph and BigWig/WIG.

---

## 7) Examples of Output

1. **Trimming and QC**  
  + FastQC HTML reports in `results/qc/fastqc/`  
  + Trimmed FASTQs in `results/trimmed/`

2. **Aligned Files**  
  + Primary BAM in `results/alignment/scer`  
  + Spike-in BAM in `results/alignment/spikein`

3. **Spike-In Factors**  
  + `results/spikein_factors/spikein_factors.csv` listing scer/dmel read counts and a `spikein_factor` for each sample

4. **Coverage Tracks** (BigWigs)  
  + `*_raw.bw` in `results/bigwig/raw/`  
  + `*_cpm.bw` in `results/bigwig/cpm/`  
  + `*_SpikeIn.bw` in `results/bigwig/spikein/`  

5. **CPM BedGraphs**
  + `*_raw.bg` in `results/bedgraph/raw/`  
  + `*_cpm.bg` in `results/bedgraph/cpm/`  
  + `*_spikein.bg` in `results/bedgraph/spikein/`    
  + Merged bedGraphs in `results/bedgraph/cpm_mean/` (averaged by `merge_group`)  

6. **Converted WIGs** (Optional)
  + `*_raw.wig` in `results/wig/raw/`  
  + `*_cpm.wig` in `results/wig/cpm/`  
  + `*_spikein.wig` in `results/wig/spikein/`       
  + Merged WIG: `results/wig/cpm_mean/{group}_cpm_mean.wig`

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
