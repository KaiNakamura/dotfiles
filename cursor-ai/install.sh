#!/bin/bash

set -e

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create target directories if they don't exist
mkdir -p ~/.cursor/commands
mkdir -p ~/.cursor/rules

# Copy commands directory (overwrites existing files)
cp -r "$WORKDIR/commands/"* ~/.cursor/commands/

# Copy rules directory (overwrites existing files)
cp -r "$WORKDIR/rules/"* ~/.cursor/rules/
