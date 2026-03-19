#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required to generate the source appendix manifest" >&2
  exit 1
fi

if ! command -v typst >/dev/null 2>&1; then
  echo "error: typst is required to compile the source appendix PDF" >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/generate-source-appendix.py" \
  --root "$ROOT_DIR" \
  --manifest-output "$ROOT_DIR/appendix/source-code-manifest.json" \
  --typst-output "$ROOT_DIR/Appendix_3_Source_Code.typ"

typst compile \
  --root "$ROOT_DIR" \
  "$ROOT_DIR/Appendix_3_Source_Code.typ" \
  "$ROOT_DIR/Appendix_3_Source_Code.pdf"
