#!/usr/bin/env python

import sys

def bedgraph_to_wiggle(bedgraph_file, wiggle_file):
    with open(bedgraph_file, 'r') as infile, open(wiggle_file, 'w') as outfile:
        current_chrom = None

        outfile.write('track type=wiggle_0 name="converted_from_bedgraph"\n')

        for line in infile:
            if line.startswith(('#', 'track', 'browser')):  # Skip metadata lines
                continue
            
            fields = line.strip().split()
            if len(fields) != 4:  # Skip invalid lines
                continue  

            chrom, start, end, value = fields
            start, end = int(start), int(end)

            # If the chromosome changes, write a new variableStep header
            if chrom != current_chrom:
                outfile.write(f"variableStep chrom={chrom} span=1\n")
                current_chrom = chrom

            # Write each position with span=1 (convert 0-based to 1-based)
            for pos in range(start + 1, end + 1):
                outfile.write(f"{pos} {value}\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_bedgraph_to_wig.py input.bedgraph output.wig")
        sys.exit(1)
    bedgraph_to_wiggle(sys.argv[1], sys.argv[2])
