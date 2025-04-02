#!/usr/bin/env Rscript

library(ggplot2)
library(dplyr)
library(tidyr)
library(ggpubr)
library(tools)

# Args: <log_dir> <spikein_csv> <output_file>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript plot_alignment_stats.R <log_directory> <spikein_csv> <output_file>")
}

log_dir <- args[1]
spikein_csv <- args[2]
output_file <- args[3]
samples_csv <- "config/samples.csv"

# Read samples.csv
samples_df <- read.csv(samples_csv, stringsAsFactors = FALSE)
samples_df$sample <- trimws(as.character(samples_df$sample))

cat("==== DEBUG: samples_df ====\n")
print(samples_df)
cat("\n")

# Parse alignment logs
log_files <- list.files(path = log_dir, pattern = "\\.log$", full.names = TRUE)
if (length(log_files) == 0) stop("No log files found in directory: ", log_dir)

alignStats <- data.frame()

extract_num <- function(text, pattern) {
  m <- regmatches(text, regexec(pattern, text))
  if (length(m[[1]]) > 1) return(as.numeric(m[[1]][2])) else return(NA)
}

for (f in log_files) {
  sample <- trimws(file_path_sans_ext(basename(f)))
  lines <- readLines(f, warn = FALSE)

  total_reads <- extract_num(lines[1], "^([0-9]+)\\s+reads;")
  unmapped <- unique_mapped <- multimapped <- overall_rate <- NA

  for (line in lines) {
    if (grepl("aligned concordantly 0 times", line))
      unmapped <- extract_num(line, "([0-9]+)\\s+aligned concordantly 0 times")
    if (grepl("aligned concordantly exactly 1 time", line))
      unique_mapped <- extract_num(line, "([0-9]+)\\s+aligned concordantly exactly 1 time")
    if (grepl("aligned concordantly >1 times", line))
      multimapped <- extract_num(line, "([0-9]+)\\s+aligned concordantly >1 times")
    if (grepl("overall alignment rate", line))
      overall_rate <- extract_num(line, "([0-9.]+)% overall alignment rate")
  }

  alignStats <- rbind(alignStats, data.frame(
    sample = sample,
    total_reads = total_reads,
    unmapped = unmapped,
    unique = unique_mapped,
    multimapped = multimapped,
    overall_rate = overall_rate
  ))
}

alignStats$sample <- trimws(as.character(alignStats$sample))
alignStats <- alignStats %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

cat("==== DEBUG: alignStats ====\n")
print(alignStats)
cat("\n")

# Load spikein CSV and rejoin correct merge_group
spikein_data <- read.csv(spikein_csv, stringsAsFactors = FALSE)
spikein_data$sample <- trimws(as.character(spikein_data$sample))

spikein_data <- spikein_data %>%
  select(sample, scer_reads, spikein_reads, spikein_factor) %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

cat("==== DEBUG: spikein_data ====\n")
print(spikein_data)
cat("\n")

# Reorder factors
spikein_data$sample <- factor(spikein_data$sample, levels = alignStats$sample)
spikein_data$merge_group <- factor(spikein_data$merge_group, levels = unique(alignStats$merge_group))

# === Plot 1: Total paired reads ===
p1 <- ggplot(alignStats, aes(x = merge_group, y = total_reads / 1e6, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Total Reads (Millions)") +
  xlab("Group") +
  ggtitle("Total Paired-End Reads per Sample") +
  guides(fill = "none")

# === Plot 2: Overall alignment rate ===
p2 <- ggplot(alignStats, aes(x = merge_group, y = overall_rate, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Overall Alignment Rate (%)") +
  xlab("Group") +
  ggtitle("Overall Alignment Rate per Sample") +
  guides(fill = "none")

# === Plot 3: Spike-in read count ===
p3 <- ggplot(spikein_data, aes(x = merge_group, y = spikein_reads / 1e6, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Spike-In Total Reads (Millions)") +
  xlab("Group") +
  ggtitle("Spike-In Total Reads per Sample") +
  guides(fill = "none")

# === Plot 4: Spike-in factor barplot ===
p4 <- ggplot(spikein_data, aes(x = sample, y = spikein_factor, fill = merge_group)) +
  geom_bar(stat = "identity") +
  theme_bw(base_size = 14) +
  ylab("Spike-In Factor") +
  xlab("Sample") +
  ggtitle("Spike-In Factor per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  guides(fill = guide_legend(title = "Group"))

# Arrange 2x2 grid
final_plot <- ggarrange(p1, p2, p3, p4, ncol = 2, nrow = 2)

# Save
ggsave(output_file, final_plot, width = 16, height = 12)
