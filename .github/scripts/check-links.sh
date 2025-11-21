#!/bin/bash

# Custom markdown link checker script that respects file-path parameter
set -e

CONFIG_FILE="${INPUT_CONFIG_FILE:-}"
FILE_PATH="${INPUT_FILE_PATH:-}"

# Install markdown-link-check if not present
if ! command -v markdown-link-check &> /dev/null; then
    echo "Installing markdown-link-check..."
    npm install -g markdown-link-check
fi

# Check if config file exists
CONFIG_ARGS=""
if [ -n "$CONFIG_FILE" ]; then
    # Try to find config file in current directory or parent directories
    if [ -f "$CONFIG_FILE" ]; then
        CONFIG_ARGS="--config $CONFIG_FILE"
    elif [ -f "../$CONFIG_FILE" ]; then
        CONFIG_ARGS="--config ../$CONFIG_FILE"
    elif [ -f "../../$CONFIG_FILE" ]; then
        CONFIG_ARGS="--config ../../$CONFIG_FILE"
    else
        echo "Config file specified but not found: $CONFIG_FILE"
    fi
else
    echo "No config file specified"
fi

# Process file paths
if [ -n "$FILE_PATH" ]; then
    # Split comma-separated file paths and check each one
    IFS=',' read -ra FILES <<< "$FILE_PATH"
    for file in "${FILES[@]}"; do
        # Trim whitespace
        file=$(echo "$file" | xargs)
        if [ -f "$file" ]; then
            markdown-link-check $CONFIG_ARGS "$file"
        else
            echo "Warning: File not found: $file"
        fi
    done
else
    find . -name '*.md' -not -path './node_modules/*' -not -path './lib/*' -exec markdown-link-check $CONFIG_ARGS '{}' ';'
fi
