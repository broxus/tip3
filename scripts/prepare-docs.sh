#!/usr/bin/env bash

set -o errexit

OUTDIR="$(node -p 'require("./docs/config.js").outputDir')"

if [ ! -d node_modules ]; then
  npm ci
fi

rm -rf "$OUTDIR"

node scripts/gen-docs.js

node scripts/gen-nav.js "$OUTDIR" > "$OUTDIR/../nav.adoc"
