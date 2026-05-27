#!/usr/bin/env bash
# Run via assets/package.json "deploy" from gigalixir-buildpack-phoenix-static (npm install runs first).
set -euo pipefail

cd "$(dirname "$0")/.."

mix assets.deploy
rm -f _build/esbuild*
