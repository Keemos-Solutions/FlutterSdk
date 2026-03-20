#!/usr/bin/env bash
set -euo pipefail

SPEC=openapi-user-only.yaml
OUT=./generated

if ! command -v openapi-generator-cli >/dev/null 2>&1; then
  echo "openapi-generator-cli not found. Install it from https://openapi-generator.tech/"
  echo "Or run: npm install @openapitools/openapi-generator-cli -g"
  exit 1
fi

openapi-generator-cli generate -i "$SPEC" -g dart-dio -o "$OUT" --additional-properties=pubName=keemos_sdk_generated

echo "Generated SDK in $OUT. Review and copy models/clients into lib/src/ as needed."
