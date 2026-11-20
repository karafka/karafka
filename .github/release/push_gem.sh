#!/usr/bin/env bash
# Signs a gem with Sigstore and pushes it with the attestation. Exits before the push when
# signing fails, so no gem is published without its attestation.
set -euo pipefail

gem_file="$1"

"$(dirname "$0")/sigstore.sh" sign "$gem_file" --bundle "$gem_file.sigstore.json"
gem push "$gem_file" --attestation "$gem_file.sigstore.json"
