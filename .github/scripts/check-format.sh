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
  if [[ ! -f "$file" || $(basename "$file") =~ yarn\.lock|package-lock\.json|.*\.spkg|Dockerfile ]]; then
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
        if [ "$(gofmt $OPTIONS -l "$file" | wc -l)" -ne 0 ]; then
          UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
        fi
      fi
      ;;
    *)
      echo "Unsupported formatter: $FORMATTER"
      exit 1
      ;;
  esac
done <<< "$CHANGED_FILES"

# Output results
if [ -n "$UNFORMATTED_FILES" ]; then
  # Displays in Github Summary. The sed command replaces all literal newlines with %0A (URL-encoded newline) for proper display
  echo "::notice::Files needing formatting with ${FORMATTER}:%0A$(echo -e "$UNFORMATTED_FILES" | sed ':a;N;$!ba;s/\n/%0A/g')" >&2

  echo "unformatted_files<<EOF"
  echo -e "$UNFORMATTED_FILES"
  echo "EOF"
  exit 1
else
  echo "unformatted_files<<EOF"
  echo ""
  echo "EOF"
  exit 0
fi
