#!/usr/bin/env Rscript

library(ggplot2)
library(dplyr)
library(tidyr)
library(ggpubr)
library(tools)

# Arguments
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
samples_df$sample <- file_path_sans_ext(basename(samples_df$sample))  # Normalize

# List log files
log_files <- list.files(path = log_dir, pattern = "\\.log$", full.names = TRUE)
if (length(log_files) == 0) stop("No log files found in directory: ", log_dir)

alignStats <- data.frame()

extract_num <- function(text, pattern) {
  m <- regmatches(text, regexec(pattern, text))
  if (length(m[[1]]) > 1) return(as.numeric(m[[1]][2])) else return(NA)
}

# Parse logs
for (f in log_files) {
  sample <- file_path_sans_ext(basename(f))
  sample <- gsub("_filtered$", "", sample)
  lines <- readLines(f, warn = FALSE)
  if (length(lines) == 0) next

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

# Merge group
alignStats <- alignStats %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

# Spike-in info
spikein_data <- read.csv(spikein_csv, stringsAsFactors = FALSE)
spikein_data$sample <- file_path_sans_ext(basename(spikein_data$sample))
spikein_data <- spikein_data %>%
  left_join(samples_df[, c("sample", "merge_group")], by = "sample")

# Plot 1: Total Reads
p1 <- ggplot(alignStats, aes(x = merge_group, y = total_reads / 1e6, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Total Reads (Millions)") +
  xlab("Group") +
  ggtitle("Total Reads per Sample") +
  guides(fill = "none")

# Plot 2: Overall Alignment Rate
p2 <- ggplot(alignStats, aes(x = merge_group, y = overall_rate, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Overall Alignment Rate (%)") +
  xlab("Group") +
  ggtitle("Overall Alignment Rate per Sample") +
  guides(fill = "none")

# Plot 3: Spike-in Total Reads
p3 <- ggplot(spikein_data, aes(x = merge_group, y = spikein_reads / 1e6, fill = merge_group)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, size = 2) +
  theme_bw(base_size = 14) +
  ylab("Spike-In Reads (Millions)") +
  xlab("Group") +
  ggtitle("Spike-In Reads per Sample") +
  guides(fill = "none")

# Order samples within each merge group
spikein_data <- spikein_data %>%
  arrange(merge_group, sample)

# Create factor for 'sample' with levels in the desired order
spikein_data$sample <- factor(spikein_data$sample, levels = unique(spikein_data$sample))

# Plot 4: Spike in factor Barplot
p4 <- ggplot(spikein_data, aes(x = sample, y = spikein_factor, fill = merge_group)) +
  geom_bar(stat = "identity") +
  theme_bw(base_size = 14) +
  ylab("Spike-In Factor") +
  xlab("Sample") +
  ggtitle("Spike-In Factor per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_fill_brewer(palette = "Set2")


# Combine
final_plot <- ggarrange(p1, p2, p3, p4, ncol = 2, nrow = 2)

# Save
ggsave(output_file, final_plot, width = 16, height = 12)
