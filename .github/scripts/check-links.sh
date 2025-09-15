#!/bin/bash

# Custom markdown link checker script that respects file-path parameter
set -e

CONFIG_FILE="${INPUT_CONFIG_FILE:-}"
FILE_PATH="${INPUT_FILE_PATH:-}"

echo "Config file: $CONFIG_FILE"
echo "File paths: $FILE_PATH"

# Install markdown-link-check if not present
if ! command -v markdown-link-check &> /dev/null; then
    echo "Installing markdown-link-check..."
    npm install -g markdown-link-check
fi

# Check if config file exists
CONFIG_ARGS=""
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo "Using config file: $CONFIG_FILE"
    CONFIG_ARGS="--config $CONFIG_FILE"
else
    echo "No config file found or specified"
fi

# Process file paths
if [ -n "$FILE_PATH" ]; then
    echo "Checking specific files: $FILE_PATH"
    # Split comma-separated file paths and check each one
    IFS=',' read -ra FILES <<< "$FILE_PATH"
    for file in "${FILES[@]}"; do
        # Trim whitespace
        file=$(echo "$file" | xargs)
        if [ -f "$file" ]; then
            echo "Checking: $file"
            markdown-link-check $CONFIG_ARGS "$file"
        else
            echo "Warning: File not found: $file"
        fi
    done
else
    echo "No specific files provided, falling back to find all .md files"
    find . -name '*.md' -not -path './node_modules/*' -exec markdown-link-check $CONFIG_ARGS '{}' ';'
fi
