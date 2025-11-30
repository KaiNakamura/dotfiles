#!/bin/bash

set -e

# Get the directory where this script is located
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create target directory if it doesn't exist
mkdir -p ~/.cursor/commands

# Copy commands directory (overwrites existing files)
cp -r "$WORKDIR/commands/"* ~/.cursor/commands/

