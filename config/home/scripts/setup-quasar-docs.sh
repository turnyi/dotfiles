#!/bin/bash

# Setup Quasar documentation for Docs MCP Server
set -euo pipefail

echo "Setting up Quasar documentation for MCP server..."

# Start the docs MCP server in the background
echo "Starting docs MCP server..."
OPENAI_API_KEY="$OPENAI_API_KEY" npx @arabold/docs-mcp-server@latest serve --port 6280 &
SERVER_PID=$!

# Wait for server to start
sleep 5

echo "Scraping Quasar documentation..."

# Scrape main Quasar docs
npx @arabold/docs-mcp-server@latest scrape quasar https://quasar.dev/docs/ --server-url http://localhost:6280/api

# Scrape components documentation
npx @arabold/docs-mcp-server@latest scrape quasar-components https://quasar.dev/components/ --server-url http://localhost:6280/api

# Scrape Vue Composition API docs (useful for Quasar development)
npx @arabold/docs-mcp-server@latest scrape vue https://vuejs.org/api/ --server-url http://localhost:6280/api

echo "Documentation scraping completed!"
echo "You can now search Quasar docs with:"
echo "OPENAI_API_KEY=\"\$OPENAI_API_KEY\" npx @arabold/docs-mcp-server@latest search quasar \"component props\""

# Stop the server
kill $SERVER_PID 2>/dev/null || true

echo "Setup complete! Restart opencode to use the new MCP server."

