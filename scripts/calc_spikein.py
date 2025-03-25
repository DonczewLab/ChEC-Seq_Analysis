#!/usr/bin/env python

import sys
import re
import subprocess

if len(sys.argv) < 3:
    print("Usage: calc_spikein.py <output_csv> <scer_bams...> <dmel_bams...>")
    sys.exit(1)

out_csv = sys.argv[1]

bams_scer = []
bams_dmel = []

for arg in sys.argv[2:]:
    if "/dmel/" in arg:
        bams_dmel.append(arg)
    else:
        bams_scer.append(arg)

# Build dict keyed by sample -> {scer_bam:..., dmel_bam:...}
sample_dict = {}

def get_sample_name(path):
    base = path.split("/")[-1]  # e.g. "SampleA.bam"
    return re.sub(r"\.bam$", "", base)  # remove .bam

for b in bams_scer:
    s = get_sample_name(b)
    sample_dict.setdefault(s, {})["scer"] = b

for b in bams_dmel:
    s = get_sample_name(b)
    sample_dict.setdefault(s, {})["dmel"] = b

results = []
for sample, bams in sample_dict.items():
    scer_bam = bams.get("scer")
    dmel_bam = bams.get("dmel")

    if not scer_bam or not dmel_bam:
        # skip incomplete pairs
        continue

    # Count mapped reads in scer
    scer_cmd = ["samtools", "view", "-c", "-F", "4", scer_bam]
    scer_count = int(subprocess.check_output(scer_cmd).decode().strip())

    # Count mapped reads in dmel
    dmel_cmd = ["samtools", "view", "-c", "-F", "4", dmel_bam]
    dmel_count = int(subprocess.check_output(dmel_cmd).decode().strip())

    # Example factor: ratio = dmel_count / scer_count
    if scer_count == 0:
        factor = 1.0
    else:
        factor = dmel_count / float(scer_count)

    results.append((sample, scer_count, dmel_count, factor))

with open(out_csv, "w") as out:
    out.write("sample,scer_reads,dmel_reads,spikein_factor\n")
    for s, scer_r, dmel_r, f in sorted(results):
        out.write(f"{s},{scer_r},{dmel_r},{f}\n")

print(f"Wrote spike-in factors to {out_csv}")
