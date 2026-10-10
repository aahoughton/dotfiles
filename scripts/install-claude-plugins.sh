#!/usr/bin/env bash
# Install Claude Code plugins
# Run manually after Claude Code is installed and configured

set -euo pipefail

plugins=(
  gopls-lsp@claude-plugins-official
  swift-lsp@claude-plugins-official
  typescript-lsp@claude-plugins-official
  claude-md-management@claude-plugins-official
  feature-dev@claude-plugins-official
)

# A fresh install only knows the built-in directory until the first interactive
# session registers this marketplace. Adding it is a no-op if already present.
claude plugin marketplace add anthropics/claude-plugins-official

for plugin in "${plugins[@]}"; do
  echo "Installing $plugin..."
  claude plugin install "$plugin"
done

echo "Done."
