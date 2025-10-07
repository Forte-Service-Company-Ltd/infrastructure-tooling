#!/bin/bash
# check-versions.sh - Package version consistency and advancement checker
# Validates that all package.json files have consistent versions and that
# the version has advanced beyond the default branch.
#
# Usage: ./check-versions.sh [default-branch]
#
set -ex

DEFAULT_BRANCH=${1:-main}

# Find package.json files (excluding node_modules)
files=$(find . -path "*/node_modules" -prune -o -name "package.json" \( -path "./package.json" -o -path "./modules/*/package.json" \) -print)

[ -z "$files" ] && echo "No package.json files found" && exit 0

# Extract versions
versions=$(echo "$files" | while read -r file; do
  version=$(jq -r '.version' "$file")
  echo "$file: $version" >&2
  echo "$file|$version"
done)

# Check consistency
unique=$(echo "$versions" | cut -d'|' -f2 | sort -u | wc -l)

if [ "$unique" -gt 1 ]; then
  echo "## ❌ Inconsistent Package Versions"
  echo
  echo "$versions" | while IFS='|' read -r file ver; do
    echo "- \`${file#./}\`: **$ver**"
    echo "::error file=${file#./}::Inconsistent version: $ver" >&2
  done
  echo
  echo "All package.json files must have the same version."
  exit 1
fi

# Check version advancement
current=$(echo "$versions" | cut -d'|' -f2 | head -1)
default_version=$(git show "origin/$DEFAULT_BRANCH:package.json" 2>/dev/null | jq -r '.version' || echo "")

[ -z "$default_version" ] && echo "No package.json on default branch" >&2 && exit 0

echo "Comparing $current against $default_version" >&2

# Function to output message for use in the PR comment
version_not_incremented() {
  echo "## ⚠️ Version Not Incremented"
  echo
  echo "Current version: **$current**"
  echo "Default branch version: **$default_version**"
  echo
  echo "The version must be incremented beyond the default branch."
  echo "::error file=package.json::Version not incremented: $current (was $default_version)" >&2
  exit 1
}

# If versions are exactly the same, fail
[ "$current" = "$default_version" ] && version_not_incremented

# Strip any suffix (e.g., -rc.N) for semantic comparison
current_base="${current%%-*}"
default_base="${default_version%%-*}"

# Compare semantic versions (major.minor.patch)
IFS='.' read -r -a curr <<< "$current_base"
IFS='.' read -r -a def <<< "$default_base"

i=0
for i in major minor patch; do
  [ "${curr[$i]}" -gt "${def[$i]}" ] && echo "## ✅ Version Checks Passed" && exit 0
  [ "${curr[$i]}" -lt "${def[$i]}" ] && break
  ((i++))
done

# Base versions are equal but full versions differ (e.g., suffix changed) - that's ok
[ "$current" != "$default_version" ] && echo "## ✅ Version Checks Passed" && exit 0

version_not_incremented
