#!/usr/bin/env Rscript

# Load required libraries
library(ggplot2)
library(dplyr)
library(tidyr)
library(ggpubr)

# Capture command-line arguments:
# args[1] = alignment log directory (e.g., "results/logs/alignment/scer/")
# args[2] = spikein factors CSV (e.g., "results/spikein_factors/spikein_factors.csv")
# args[3] = output file for the final plot (e.g., "results/plots/alignment_stats.png")
args <- commandArgs(trailingOnly = TRUE)
if(length(args) < 3) {
  stop("Usage: Rscript plot_alignment_stats.R <log_directory> <spikein_csv> <output_file>")
}

log_dir <- args[1]
spikein_csv <- args[2]
output_file <- args[3]

# List all log files in the directory (assuming they end in .log)
log_files <- list.files(path = log_dir, pattern = "\\.log$", full.names = TRUE)
if(length(log_files) == 0) {
  stop("No log files found in directory: ", log_dir)
}

# Initialize an empty data frame for alignment stats
alignStats <- data.frame()

# Function to extract a number from a string given a regex pattern
extract_num <- function(text, pattern) {
  m <- regmatches(text, regexec(pattern, text))
  if(length(m[[1]]) > 1) {
    return(as.numeric(m[[1]][2]))
  } else {
    return(NA)
  }
}

# Loop through each log file and parse metrics
for (f in log_files) {
  # Extract sample name from filename (strip directory and .log)
  sample <- tools::file_path_sans_ext(basename(f))
  lines <- readLines(f, warn = FALSE)
  
  # Look for total reads (assume first line is like "7513816 reads; of these:")
  total_reads <- extract_num(lines[1], "^([0-9]+)\\s+reads;")
  
  # Look for unmapped, uniquely mapped, and multimapped counts.
  # These lines typically contain "aligned concordantly 0 times", "exactly 1 time", ">1 times"
  unmapped <- NA
  unique_mapped <- NA
  multimapped <- NA
  
  for (line in lines) {
    if (grepl("aligned concordantly 0 times", line)) {
      unmapped <- extract_num(line, "([0-9]+)\\s+aligned concordantly 0 times")
    } else if (grepl("aligned concordantly exactly 1 time", line)) {
      unique_mapped <- extract_num(line, "([0-9]+)\\s+aligned concordantly exactly 1 time")
    } else if (grepl("aligned concordantly >1 times", line)) {
      multimapped <- extract_num(line, "([0-9]+)\\s+aligned concordantly >1 times")
    }
  }
  
  # Overall alignment rate: search for a line with "overall alignment rate"
  overall_rate <- NA
  for (line in lines) {
    if (grepl("overall alignment rate", line)) {
      overall_rate <- extract_num(line, "([0-9.]+)% overall alignment rate")
      break
    }
  }
  
  # Append data for this sample
  alignStats <- rbind(alignStats, data.frame(
    sample = sample,
    total_reads = total_reads,
    unmapped = unmapped,
    unique = unique_mapped,
    multimapped = multimapped,
    overall_rate = overall_rate
  ))
}

# Plot1: Box/Bar plot of overall alignment rate
# (If replicates exist, box plot is meaningful; otherwise, bar plot.)
p1 <- ggplot(alignStats, aes(x = sample, y = overall_rate)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  theme_bw(base_size = 14) +
  ylab("Overall Alignment Rate (%)") +
  xlab("Sample") +
  ggtitle("Overall Alignment Rate per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Prepare data for Plot2 (stacked bar of mapped categories)
mappedData <- alignStats %>%
  select(sample, unique, multimapped, unmapped) %>%
  gather(key = "MappingType", value = "Count", -sample)

# Plot2: Stacked bar plot of mapping categories
p2 <- ggplot(mappedData, aes(x = sample, y = Count, fill = MappingType)) +
  geom_bar(stat = "identity") +
  theme_bw(base_size = 14) +
  ylab("Read Count") +
  xlab("Sample") +
  ggtitle("Mapping Categories per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot3: Bar plot of total reads per sample
p3 <- ggplot(alignStats, aes(x = sample, y = total_reads / 1e6)) +
  geom_bar(stat = "identity", fill = "darkgreen") +
  theme_bw(base_size = 14) +
  ylab("Total Reads (Millions)") +
  xlab("Sample") +
  ggtitle("Total Reads per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot4: Bar plot of spike-in factor.
# Read spikein_factors.csv
spikein_data <- read.csv(spikein_csv, stringsAsFactors = FALSE)
p4 <- ggplot(spikein_data, aes(x = sample, y = spikein_factor)) +
  geom_bar(stat = "identity", fill = "purple") +
  theme_bw(base_size = 14) +
  ylab("Spike-In Factor") +
  xlab("Sample") +
  ggtitle("Spike-In Factor per Sample") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Arrange the four plots into a grid
final_plot <- ggarrange(p1, p2, p3, p4, ncol = 2, nrow = 2, common.legend = TRUE, legend = "bottom")

# Save the plot
ggsave(output_file, final_plot, width = 16, height = 12)
