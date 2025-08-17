#!/usr/bin/env python3
import os, re, subprocess, sys

ALLOWED = [
    r'^Sources/App/Consolidated/',
    r'^Sources/Kits/',
    r'^Sources/SharedTypes/',
    r'^Sources/MCP[^/]+/',
    r'^Tests/',
]
ALLOWED_RE = [re.compile(p) for p in ALLOWED]

# Determine diff range
base = os.environ.get('GITHUB_BASE_REF')
head = os.environ.get('GITHUB_HEAD_REF')
ref_range = None

# On PR, ci should have fetched base; fallback to origin/base
if base:
    # Use three-dot to compare base to HEAD
    ref_range = f'origin/{base}...HEAD'
else:
    # Fallback: last commit on branch
    ref_range = 'HEAD~1..HEAD'

# Get added files in diff
try:
    out = subprocess.check_output(['git','--no-pager','diff','--name-status',ref_range], text=True)
except subprocess.CalledProcessError as e:
    print(f"Git diff failed: {e}", file=sys.stderr)
    sys.exit(2)

violations = []
for line in out.splitlines():
    parts = line.split('\t')
    if not parts:
        continue
    status = parts[0].strip()
    if status != 'A':
        continue
    if len(parts) < 2:
        continue
    path = parts[1].strip()
    if not path.endswith('.swift'):
        continue
    # Allow backup folder always
    if path.startswith('backup/'):
        continue
    allowed = any(r.match(path) for r in ALLOWED_RE)
    if not allowed:
        violations.append(path)

if violations:
    print('Path hygiene check failed. New Swift files must live under one of:')
    for p in ALLOWED:
        print(f'  - {p}')
    print('\nThe following new files violate the policy:')
    for v in violations:
        print(f'  - {v}')
    sys.exit(1)
else:
    print('Path hygiene check passed. No new Swift files outside allowed directories.')
