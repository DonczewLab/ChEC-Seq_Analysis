#!/usr/bin/env python3

import sys
import re
import subprocess

if len(sys.argv) < 3:
    print("Usage: calc_spikein.py <output_csv> <spom_bams...> <dmel_bams...>")
    sys.exit(1)

out_csv = sys.argv[1]

# We'll parse spom and dmel BAMs from the rest of the arguments
# We'll assume file names contain something like '/spom/<sample>.bam' or '/dmel/<sample>.bam'
# so we can extract sample name consistently.

bams_spom = []
bams_dmel = []
mode = 'spom'

for arg in sys.argv[2:]:
    if "/dmel/" in arg:
        bams_dmel.append(arg)
    else:
        bams_spom.append(arg)

# We assume sample names are identical across spom vs dmel, just different directory
# e.g. results/alignment/spom/SampleA.bam vs results/alignment/dmel/SampleA.bam
# Let's build a dict keyed by sample -> {spom_bam:..., dmel_bam:...}

sample_dict = {}

def get_sample_name(path):
    # e.g. "results/alignment/spom/SampleA.bam" -> "SampleA"
    # or you can do a more robust parse
    base = path.split("/")[-1]  # e.g. SampleA.bam
    return re.sub(r"\.bam$", "", base)  # remove .bam

for b in bams_spom:
    s = get_sample_name(b)
    sample_dict.setdefault(s, {})["spom"] = b

for b in bams_dmel:
    s = get_sample_name(b)
    sample_dict.setdefault(s, {})["dmel"] = b

# Now compute read counts and factor
results = []

for sample, bams in sample_dict.items():
    spom_bam = bams.get("spom")
    dmel_bam = bams.get("dmel")

    if not spom_bam or not dmel_bam:
        # skip incomplete pairs
        continue

    # Count mapped reads in spom
    spom_cmd = ["samtools", "view", "-c", "-F", "4", spom_bam]
    spom_count = int(subprocess.check_output(spom_cmd).decode().strip())

    # Count mapped reads in dmel
    dmel_cmd = ["samtools", "view", "-c", "-F", "4", dmel_bam]
    dmel_count = int(subprocess.check_output(dmel_cmd).decode().strip())

    # Example formula for factor:
    # We can define factor = (median_dmel_count / dmel_count) or
    # factor = (dmel_count / (spom_count + dmel_count)) ...
    # Here we do a simple ratio: factor = total_dmel / total_spom
    # TOTALLY UP TO YOU. Adjust as needed.
    if spom_count == 0:
        factor = 1.0
    else:
        factor = dmel_count / float(spom_count)

    results.append((sample, spom_count, dmel_count, factor))

# Write CSV
with open(out_csv, "w") as out:
    out.write("sample,spom_reads,dmel_reads,spikein_factor\n")
    for s, spom_r, dmel_r, f in sorted(results):
        out.write(f"{s},{spom_r},{dmel_r},{f}\n")

print(f"Wrote spike-in factors to {out_csv}")
