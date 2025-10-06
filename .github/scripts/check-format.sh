#!/bin/bash
set -e

# Script to check formatting on changed files
# Usage: ./format-check.sh <formatter> <path> <config-file> <changed-files>

FORMATTER="$1"
PATH_TO_CHECK="$2"
CONFIG_FILE="$3"
CHANGED_FILES="$4"

cd "$PATH_TO_CHECK"

# Build formatter command
CONFIG_ARG=""
if [ -n "$CONFIG_FILE" ]; then
  case "$FORMATTER" in
    prettier|black)
      CONFIG_ARG="--config $CONFIG_FILE"
      ;;
  esac
fi

# Run formatter on changed files
UNFORMATTED_FILES=""
while IFS= read -r file; do
  # Check if file exists (might have been deleted)
  if [ ! -f "$file" ]; then
    continue
  fi
  
  case "$FORMATTER" in
    prettier)
      if ! prettier --log-level=silent --check $CONFIG_ARG "$file" 2>/dev/null; then
        UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
      fi
      ;;
    black)
      if ! black --quiet --check $CONFIG_ARG "$file" 2>/dev/null; then
        UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
      fi
      ;;
    gofmt)
      if ! gofmt -l "$file" | grep -q .; then
        UNFORMATTED_FILES="${UNFORMATTED_FILES}${file}\n"
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
  # Displays in Github Summary
  # GitHub Actions workflow commands require URL-encoded newlines (%0A) in annotations
  # The sed command replaces all literal newlines with %0A for proper display
  echo "::notice::A. Files needing formatting with ${FORMATTER}:%0A$(echo -e "$UNFORMATTED_FILES" | sed ':a;N;$!ba;s/\n/%0A/g')" >&2
  echo "::notice::B. Files needing formatting with ${FORMATTER}: $UNFORMATTED_FILES" >&2
  echo -e "::notice::C. Files needing formatting with ${FORMATTER}: $UNFORMATTED_FILES" >&2

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
