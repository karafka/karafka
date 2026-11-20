#!/usr/bin/env bash
# Runs sigstore-cli with the given arguments (e.g. sign, verify)
set -euo pipefail

gem install sigstore-cli -v 0.2.3 --no-document
gem install json -v 2.21.2 --no-document

# sigstore-cli does not work with json 3.x, the default of Ruby 4.0
ruby -e 'gem "json", "2.21.2"; load Gem.bin_path("sigstore-cli", "sigstore-cli")' "$@"
