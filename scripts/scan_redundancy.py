#!/usr/bin/env python3
import os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

swift_files = []
for base, _, files in os.walk(ROOT):
    # Skip build and VCS dirs
    if any(skip in base for skip in [
        f"{os.sep}.git{os.sep}",
        f"{os.sep}.build{os.sep}",
        f"{os.sep}build{os.sep}",
        f"{os.sep}DerivedData{os.sep}",
        f"{os.sep}fastlane{os.sep}",
        f"{os.sep}backup{os.sep}"
    ]):
        continue
    for f in files:
        if f.endswith('.swift'):
            swift_files.append(os.path.join(base, f))

# Zero-byte files
zero_byte = [p for p in swift_files if os.path.getsize(p) == 0]

# Duplicate basenames
by_name = defaultdict(list)
for p in swift_files:
    by_name[os.path.basename(p)].append(p)

duplicates = {name: paths for name, paths in by_name.items() if len(paths) > 1}

print("=== Redundancy Scan Summary ===")
print(f"Root: {ROOT}")
print(f"Total Swift files: {len(swift_files)}")
print(f"Zero-byte Swift files: {len(zero_byte)}")
for p in zero_byte:
    print(f"  [0B] {os.path.relpath(p, ROOT)}")

print(f"\nDuplicate filenames: {len(duplicates)} (same name, possibly different content)")
for name, paths in sorted(duplicates.items()):
    print(f"\n- {name}")
    for p in sorted(paths):
        print(f"    · {os.path.relpath(p, ROOT)}")

print("\nTip: Prefer a single canonical definition for shared utilities (AudioProcessingConfiguration, AudioPerformanceMonitor, AudioBufferPool, AudioFeatures). Move them into Sources/Kits/AudioKit and update imports.")
