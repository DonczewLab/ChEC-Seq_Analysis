# SLAMseq_Analysis

# 2) Instructions to run on Slurm managed HPC
2A. Clone repository
```
git clone https://github.com/JK-Cobre-Help/CutandTag_Analysis_Snakemake.git
```
2B. Load modules
```
module purge
module load slurm python/3.10 pandas/2.2.3 numpy/1.22.3 matplotlib/3.7.1
```
2C. Modify samples and config file
```
vim samples.csv
vim config.yml
```
2D. Dry Run
```
snakemake -npr
```
2E. Run on HPC with config.yml options
```
sbatch --wrap="snakemake -j 999 --use-envmodules --latency-wait 60 --cluster-config config/cluster_config.yml --cluster 'sbatch -A {cluster.account} -p {cluster.partition} --cpus-per-task {cluster.cpus-per-task}  -t {cluster.time} --mem {cluster.mem} --output {cluster.output}'"
```
