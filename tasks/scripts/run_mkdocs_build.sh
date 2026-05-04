#!/bin/bash

source ./tasks/shims/activate_venv

output=$(uv pip show mkdocs-material &> /dev/null)
if [ $? -eq 0 ]
then
    echo "Building MkDocs docs..."
    mkdocs build --strict || exit 1
    echo "Built Docs!"
fi
