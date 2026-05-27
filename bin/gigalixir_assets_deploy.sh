#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

npm --prefix assets ci --omit=dev
mix assets.deploy
rm -f _build/esbuild*
