#!/bin/bash
set -e

# Script to check formatting on changed files
# Usage: ./check-format.sh <formatter> <options> <changed-files>

FORMATTER="$1"
OPTIONS="$2"
CHANGED_FILES="$3"

# Run formatter on changed files
UNFORMATTED_FILES=""
while IFS= read -r file; do
  # Ignore non-existent files (deleted in PR), and these ineligible files
  # - Disable Dockerfile until https://github.com/reteps/dockerfmt/issues/25 is resolved
  if [[ ! -f "$file" || $(basename "$file") =~ yarn\.lock|package-lock\.json|.*\.spkg|.*\.svg|\.env.*|Dockerfile|Makefile ]]; then
    echo "Ignoring file: $file" >&2
    continue
  fi
  
  case "$FORMATTER" in
    prettier)
      if ! prettier --plugin=prettier-plugin-sh --log-level=error --check $OPTIONS "$file"; then
        UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
      fi
      ;;
    black)
      # Restrict to .py files
      if [[ "$file" == *.py ]]; then
        if ! black --quiet --check $OPTIONS "$file"; then
          UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
        fi
      fi
      ;;
    gofmt)
      # Restrict to .go files
      if [[ "$file" == *.go ]]; then
        # gofmt always returns 0, so we check if there's any output (no output: passing)
        if ! formatted_output=$(gofmt $OPTIONS -l "$file"); then
          echo "gofmt failed for: $file" >&2
          exit 1
        fi
        if [ -n "$formatted_output" ]; then
          UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
        fi
      fi
      ;;
    *)
      echo "Unsupported formatter: $FORMATTER" >&2
      exit 1
      ;;
  esac
done <<< "$CHANGED_FILES"

##  Additional project-wide checks
# 1. Golang: go mod tidy
if [ "$FORMATTER" == "gofmt" ]; then
  # Run go mod tidy and check if it modifies the files
  go mod tidy
  if ! git diff --exit-code go.mod go.sum > /dev/null 2>&1; then
    UNFORMATTED_FILES="${UNFORMATTED_FILES}go.mod\n"
    UNFORMATTED_FILES="${UNFORMATTED_FILES}go.sum\n"
  fi
fi

# Output results
if [ -n "$UNFORMATTED_FILES" ]; then
  # Displays in Github Summary. The sed command replaces all literal newlines with %0A (URL-encoded newline) for proper display
  echo "::notice::Files needing formatting with ${FORMATTER}:%0A$(echo -e "$UNFORMATTED_FILES" | sed ':a;N;$!ba;s/\n/%0A/g')" >&2

  output_delimiter="ghadelim_$(openssl rand -hex 16)"
  echo "unformatted_files<<$output_delimiter"
  echo -e "$UNFORMATTED_FILES"
  echo "$output_delimiter"
  exit 1
else
  output_delimiter="ghadelim_$(openssl rand -hex 16)"
  echo "unformatted_files<<$output_delimiter"
  echo ""
  echo "$output_delimiter"
  exit 0
fi
