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
  if [ -z "$file" ]; then
    continue
  fi
  
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
    *)
      echo "Unsupported formatter: $FORMATTER"
      exit 1
      ;;
  esac
done <<< "$CHANGED_FILES"

# Output results
if [ -n "$UNFORMATTED_FILES" ]; then
  # Displays in Github Summary
  echo -e "::notice::Files needing formatting with ${FORMATTER}: $UNFORMATTED_FILES" >&2

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
