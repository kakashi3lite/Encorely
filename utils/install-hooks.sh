#!/bin/bash

# Install git hooks
echo "Installing git hooks..."

# Create symbolic link or copy pre-commit hook
if [ -f .git/hooks/pre-commit ]; then
  echo "Existing pre-commit hook found. Creating backup..."
  mv .git/hooks/pre-commit .git/hooks/pre-commit.backup
fi

cp utils/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "Pre-commit hook installed successfully!"
