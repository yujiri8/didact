#!/bin/sh
set -e

pre-build-scripts/gen-templates.sh
crystal build src/scripts/tmpl.cr -o didact-template --release
crystal build src/main.cr -o didact-server --release
cd js
npm run build
