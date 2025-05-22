#!/bin/bash

# Pre-commit hook to validate assets
# Place this file in .git/hooks/pre-commit and make it executable

set -e

echo "Running asset validation..."

# Save current staged files
STAGED_FILES=$(git diff --name-only --cached)

# Check if any asset files have changed
ASSET_CHANGES=$(git diff --name-only --cached Assets.xcassets/)

if [ -n "$ASSET_CHANGES" ]; then
  echo "Asset changes detected. Running validation..."
  
  # Run validation script
  swift utils/AssetPipelineRunner.swift
  
  # If validation succeeded, update the manifest
  if [ $? -eq 0 ]; then
    echo "Assets validated successfully"
    
    # Stage the updated manifest
    git add ASSET_MANIFEST.json
  else
    echo "Asset validation failed. Please fix the issues before committing."
    exit 1
  fi
fi

exit 0
