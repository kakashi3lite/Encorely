#!/bin/bash

# Branch Protection Setup Script for AI-Mixtapes
# This script configures branch protection rules for the repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="AI-Mixtapes"
REPO_NAME="AI-Mixtapes"
GITHUB_TOKEN="${GITHUB_TOKEN}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub CLI${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

echo -e "${BLUE}Setting up branch protection rules for ${REPO_OWNER}/${REPO_NAME}${NC}"

# Function to create branch protection rule
create_branch_protection() {
    local branch=$1
    local required_checks=$2
    local required_reviewers=$3
    local dismiss_stale=$4
    local require_code_owner=$5
    local restrict_pushes=$6
    
    echo -e "${YELLOW}Configuring protection for branch: ${branch}${NC}"
    
    # Build the protection rule
    local protection_rule="{"
    protection_rule+="\"required_status_checks\":{\"strict\":true,\"checks\":[${required_checks}]},"
    protection_rule+="\"enforce_admins\":false,"
    protection_rule+="\"required_pull_request_reviews\":{\"required_approving_review_count\":${required_reviewers},\"dismiss_stale_reviews\":${dismiss_stale},\"require_code_owner_reviews\":${require_code_owner}},"
    protection_rule+="\"restrictions\":${restrict_pushes},"
    protection_rule+="\"allow_force_pushes\":false,"
    protection_rule+="\"allow_deletions\":false,"
    protection_rule+="\"block_creations\":false,"
    protection_rule+="\"required_conversation_resolution\":true"
    protection_rule+="}"
    
    # Apply the protection rule using GitHub API
    curl -X PUT \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/branches/${branch}/protection" \
        -d "${protection_rule}" \
        --silent --show-error
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Branch protection configured for ${branch}${NC}"
    else
        echo -e "${RED}✗ Failed to configure protection for ${branch}${NC}"
    fi
}

# Main branch protection (strictest)
echo -e "${BLUE}Configuring main branch protection...${NC}"
MAIN_CHECKS='"CI / Build and Test","CI / Security Scan","CI / Performance Tests","dependency-review"'
create_branch_protection "main" "${MAIN_CHECKS}" 2 true true "null"

# Develop branch protection
echo -e "${BLUE}Configuring develop branch protection...${NC}"
DEVELOP_CHECKS='"CI / Build and Test","CI / Security Scan"'
create_branch_protection "develop" "${DEVELOP_CHECKS}" 1 true true "null"

# Release branch protection
echo -e "${BLUE}Configuring release/* branch protection...${NC}"
RELEASE_CHECKS='"CI / Build and Test","CI / Security Scan","CI / Performance Tests"'
create_branch_protection "release/*" "${RELEASE_CHECKS}" 2 true true "null"

# Hotfix branch protection
echo -e "${BLUE}Configuring hotfix/* branch protection...${NC}"
HOTFIX_CHECKS='"CI / Build and Test","CI / Security Scan"'
create_branch_protection "hotfix/*" "${HOTFIX_CHECKS}" 1 false true "null"

echo -e "${GREEN}Branch protection setup completed!${NC}"

# Display current protection status
echo -e "${BLUE}Current branch protection status:${NC}"
gh api repos/${REPO_OWNER}/${REPO_NAME}/branches --jq '.[] | select(.protected == true) | {name: .name, protection: .protection}'

echo -e "${GREEN}Setup complete! Branch protection rules are now active.${NC}"
echo -e "${YELLOW}Note: Make sure to update required status checks as your CI/CD pipeline evolves.${NC}"