#!/bin/bash

echo "Ensuring project directory has a Git repository initialized..."
# Git is a pre-condition for using pyproject.toml with VCS-based dynamic versioning
if [ ! -d ".git" ]; then
    echo "Error: No Git repository found!"
    exit 1
fi

# Ideally remove this duplication via https://github.com/astral-sh/uv/issues/10547
uv_version="0.10.2" # Sync with .pre-commit-config.yaml and pyproject.toml

export PATH="$PATH:$HOME/.local/bin"
# Legacy install support < v0.5.0
export PATH="$PATH:$HOME/.cargo/bin"

echo "Ensuring uv is installed at v$uv_version..."

# Check if the uv command exists
if ! output=$(command -v uv)
then
    need_to_install=true
else
    # Check if the installed uv version matches the required version
    # uv self version outputs in the format:
    # uv 0.7.13 (62ed17b23 2025-06-12)
    # so we extract the second word
    output=$(uv self version)
    if [ $? -ne 0 ]
    then
        # if uv self version fails, we assume uv isn't installed (or is installed to
        # a version that violates the declared required version in pyproject.toml)
        need_to_install=true
    else
        need_to_install=false

        # Don't need to install from scratch, but try to do a version update if the
        # versions don't match.
        installed_version=$(echo "$output" | awk '{print $2}')
        if [ "$installed_version" != "$uv_version" ]
        then
            # The versions don't match, try to update
            output=$(uv self update $uv_version 2>&1)
            if [ $? -ne 0 ]
            then
                # Sometimes updates will fail. But if `uv self version` runs then at
                # least we have a uv install. This might be due to GitHub rate limiting,
                # for example, so there's not much point in trying to re-install. Let's
                # just use the uv version that's already installed and warn the user.
                echo "Warning: Failed to update uv to v$uv_version, using installed v$installed_version"
            fi
        fi
    fi
fi

if [ "$need_to_install" = true ]
then
    if [ -n "$WINDIR" ]
    then
        # If in Windows
        if command -v pwsh &> /dev/null
        then
            output=$(pwsh -Command "irm https://astral.sh/uv/$uv_version/install.ps1 | iex" 2>&1)
        elif command -v powershell &> /dev/null
        then
            output=$(powershell -Command "irm https://astral.sh/uv/$uv_version/install.ps1 | iex" 2>&1)
        else
            output=$(C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "irm https://astral.sh/uv/$uv_version/install.ps1 | iex" 2>&1)
        fi
    else
        # Otherwise, assume in Linux, and we might be in CI so use backoff
        for i in 1 2 3; do
            curl -LsSf https://astral.sh/uv/$uv_version/install.sh -o install-uv.sh && break 2>&1
            sleep $((2**i))
        done
        chmod +x install-uv.sh
        output=$(./install-uv.sh 2>&1)
        rm -f install-uv.sh
    fi

    if [ $? -ne 0 ]
    then
        echo "$output"
        echo "Error: Failed to install uv at v$uv_version!"
        exit 1
    fi
fi
