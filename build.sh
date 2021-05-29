#!/bin/sh
set -e

pre-build-scripts/gen-templates.sh
crystal build src/scripts/tmpl.cr -o didact-template --release
crystal build src/main.cr -o didact-server --release
crystal build src/scripts/email-subscribers.cr -o email-subscribers --release
cd js
npm run build
