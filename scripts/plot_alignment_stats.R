#!/usr/bin/env Rscript

# Load required libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(ggpubr)
library(tools)

# Arguments: <log_dir> <spikein_csv> <output_file>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript plot_alignment_stats.R <log_directory> <spikein_csv> <output_file>")
}

log_dir <- args[1]
spikein_csv <- args[2]
output_file <- args[3]
samples_csv <- "config/samples.csv"

# Load sample metadata
samples_df <- read.csv(samples_csv, stringsAsFactors = FALSE) %>%
  mutate(sample = trimws(sample))

# Load alignment log files
log_files <- list.files(path = log_dir, pattern = "\\.log$", full.names = TRUE)
if (length(log_files) == 0) stop("No log files found in directory: ", log_dir)

# Extract numbers using regex
extract_num <- function(text, pattern) {
  m <- regmatches(text, regexec(pattern, text))
  if (length(m[[1]]) > 1) as.numeric(m[[1]][2]) else NA
}

# Parse alignment logs
alignStats <- do.call(rbind, lapply(log_files, function(f) {
  sample <- trimws(file_path_sans_ext(basename(f)))
  lines <- readLines(f, warn = FALSE)
  
  data.frame(
    sample = sample,
    total_reads = extract_num(lines[1], "^([0-9]+)\\s+reads;"),
    unmapped = extract_num(lines[grepl("aligned concordantly 0 times", lines)], "([0-9]+)\\s+aligned concordantly 0 times"),
    unique = extract_num(lines[grepl("aligned concordantly exactly 1 time", lines)], "([0-9]+)\\s+aligned concordantly exactly 1 time"),
    multimapped = extract_num(lines[grepl("aligned concordantly >1 times", lines)], "([0-9]+)\\s+aligned concordantly >1 times"),
    overall_rate = extract_num(lines[grepl("overall alignment rate", lines)], "([0-9.]+)% overall alignment rate")
  )
}))

# Join merge group info
alignStats <- alignStats %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

# Load spike-in data and join merge group info
spikein_data <- read.csv(spikein_csv, stringsAsFactors = FALSE) %>%
  mutate(sample = trimws(sample)) %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

# Reorder factor levels for consistency
spikein_data$sample <- factor(spikein_data$sample, levels = alignStats$sample)
spikein_data$merge_group <- factor(spikein_data$merge_group, levels = unique(alignStats$merge_group))

# Load CPM scale factors
cpm_data <- read.csv("results/scale_reads/cpm_scale_factors.csv", stringsAsFactors = FALSE) %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

# Ensure factor levels match for plotting
cpm_data$sample <- factor(cpm_data$sample, levels = alignStats$sample)
cpm_data$merge_group <- factor(cpm_data$merge_group, levels = unique(alignStats$merge_group))

# Plot 1: Total paired-end reads
p1 <- ggplot(alignStats, aes(x = merge_group, y = total_reads / 1e6, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Total Reads (Millions)") +
  xlab("Group") +
  ggtitle("Total Paired-End Reads per Sample") +
  guides(fill = "none")

# Plot 2: Overall alignment rate
p2 <- ggplot(alignStats, aes(x = merge_group, y = overall_rate, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Overall Alignment Rate (%)") +
  xlab("Group") +
  ggtitle("Overall Alignment Rate per Sample") +
  guides(fill = "none")

# Plot 3: Spike-in reads
p3 <- ggplot(spikein_data, aes(x = merge_group, y = spikein_reads / 1e6, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Spike-In Total Reads (Millions)") +
  xlab("Group") +
  ggtitle("Spike-In Total Reads per Sample") +
  guides(fill = "none")

# Plot 4: Spike-in factor per sample (bar plot)
p4 <- ggplot(spikein_data, aes(x = sample, y = spikein_factor, fill = merge_group)) +
  geom_bar(stat = "identity", alpha = 0.7) +
  theme_bw(base_size = 14) +
  ylab("Spike-In Factor") +
  xlab("Sample") +
  ggtitle("Spike-In Factor per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  guides(fill = guide_legend(title = "Group"))

# Plot 5: Inverse Spike-in factor per sample (bar plot)
p5 <- ggplot(spikein_data, aes(x = sample, y = inverse_spikein_factor, fill = merge_group)) +
  geom_bar(stat = "identity", alpha = 0.7) +
  theme_bw(base_size = 14) +
  ylab("Inverse Spike-In Factor") +
  xlab("Sample") +
  ggtitle("Inverse Spike-In Factor (used in scaling)") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  guides(fill = guide_legend(title = "Group"))

# Plot 6: CPM Scaling Factor per sample (bar plot)
p6 <- ggplot(cpm_data, aes(x = sample, y = scale_factor_cpm, fill = merge_group)) +
  geom_bar(stat = "identity", alpha = 0.7) +
  theme_bw(base_size = 14) +
  ylab("CPM Scale Factor") +
  xlab("Sample") +
  ggtitle("CPM Scale Factor per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  guides(fill = guide_legend(title = "Group"))

# Combine plots
final_plot <- ggarrange(p1, p2, p3, p4, p5, p6, ncol = 2, nrow = 3)

# Save to file
ggsave(output_file, final_plot, width = 16, height = 18)
