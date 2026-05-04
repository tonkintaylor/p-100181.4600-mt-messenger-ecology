#!/bin/bash

echo "Syncing environment..."
output=$(uv sync 2>&1)
if [ $? -ne 0 ]
then
    echo "$output"
    echo "Error: Failed to sync the environment."
    exit 1
fi

echo "Syncing hook versions with lockfile..."
output=$(uv run sync-with-uv 2>&1)
if [ $? -ne 0 ]
then
    # Fallback to using uvx if sync-with-uv is not installed
    output=$(uvx sync-with-uv 2>&1)
    # Give up if this fails, perhaps hooks haven't been configured for the project.
fi
