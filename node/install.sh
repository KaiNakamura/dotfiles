#!/bin/bash

# Install Node.js (via brew). Needed for tooling that shells out to `node`,
# e.g. Claude Code plugin hooks (the caveman plugin's SessionStart /
# UserPromptSubmit hooks run node scripts). Claude Code itself is a native
# binary and does not require system node, but plugin hooks do.
brew install node
