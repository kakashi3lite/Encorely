#!/usr/bin/env python3
import re
from collections import Counter

# Read the project file
with open('/Users/kakashi3lite/Documents/AI-Mixtapes/AI-Mixtapes.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Find the main app Sources section (DD9B493FC570EE3F155BC4F2)
main_sources_start = content.find('DD9B493FC570EE3F155BC4F2 /* Sources */ = {')
if main_sources_start == -1:
    print('Could not find main Sources section')
    exit(1)

# Find the files section within this Sources build phase
files_start = content.find('files = (', main_sources_start)
files_end = content.find(');', files_start)
sources_section = content[files_start:files_end]

# Extract all file entries with their full lines
file_pattern = r'\t\t\t\t([A-F0-9]+) /\* (.+?\.swift) in Sources \*/,'
matches = re.findall(file_pattern, sources_section)

print(f"Found {len(matches)} total file entries in main Sources section")
if matches:
    print(f"Sample entries: {matches[:3]}")

# Find duplicates
file_counts = Counter([match[1] for match in matches])
duplicates = [filename for filename, count in file_counts.items() if count > 1]

print('Duplicate files found:')
for dup in duplicates:
    print(f'  {dup} (appears {file_counts[dup]} times)')

# Create a mapping of files to keep (first occurrence)
files_to_keep = {}
files_to_remove = []

for file_id, filename in matches:
    if filename not in files_to_keep:
        files_to_keep[filename] = file_id
    else:
        files_to_remove.append(file_id)

print(f'\nRemoving {len(files_to_remove)} duplicate entries...')

# Remove duplicate lines
new_content = content
for file_id in files_to_remove:
    # Find and remove the line with this file_id
    pattern = f'\t\t\t\t{file_id} /\* .+? in Sources \*/,\n'
    new_content = re.sub(pattern, '', new_content, flags=re.MULTILINE)

# Write the fixed content back
with open('/Users/kakashi3lite/Documents/AI-Mixtapes/AI-Mixtapes.xcodeproj/project.pbxproj', 'w') as f:
    f.write(new_content)

print('Fixed project.pbxproj file!')