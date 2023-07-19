#!/usr/bin/env bash

set -o errexit

echo 'TEST'
OUTDIR="$(node -p 'require("./docs/config.js").outputDir')"

if [ ! -d node_modules ]; then
  npm ci
fi

#rm -rf "$OUTDIR"

echo 'TEST2'
node scripts/helpers/gen-docs.js

echo 'TEST3'
node scripts/helpers/gen-nav.js "$OUTDIR" > "../nav.adoc"
