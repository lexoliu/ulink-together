#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# package-ia.sh — Build an IB-ready submission bundle
#
# Produces the exact folder layout the IB moderator expects
# (mirrors the official NIck-2 sample):
#
#   output/0011_lyj129/
#   ├── cover_page.htm
#   ├── Documentation/
#   │   ├── Crit_A_Planning.pdf
#   │   ├── Crit_B_Design.pdf
#   │   ├── Crit_B_Record_of_tasks.pdf
#   │   ├── Crit_C_Development.pdf
#   │   ├── Crit_D_Video.mp4
#   │   ├── Crit_E_Evaluation.pdf
#   │   ├── Appendix_1_Consultation.pdf
#   │   ├── Appendix_2_Feedback.pdf
#   │   └── Appendix_3_Source_Code.pdf
#   └── Product/
#       └── (self-contained source tree)
#
# It also produces  output/0011_lyj129.zip  ready for upload.
#
# Usage:  ./scripts/package-ia.sh
# ──────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANDIDATE_CODE="lyj129"
SESSION="0011"
BUNDLE="${SESSION}_${CANDIDATE_CODE}"
OUT="$REPO_ROOT/output/$BUNDLE"
ZIP_PATH="$REPO_ROOT/output/${BUNDLE}.zip"

# Allow piecewise runs via environment flag, e.g. SKIP_SOURCE_APPENDIX=1.
SKIP_SOURCE_APPENDIX="${SKIP_SOURCE_APPENDIX:-}"

# ── 0. Preflight: check required tools ──────────────────────

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' is required but not in PATH." >&2; exit 1; }
}

need typst
need rsync
need zip

echo "==> Wiping previous output at $OUT …"
rm -rf "$OUT" "$ZIP_PATH"
mkdir -p "$OUT/Documentation"

# ── 1. Compile Typst documents into Documentation/ ──────────

echo "==> Compiling criterion documents …"

typst compile "$REPO_ROOT/doc/Crit_A_Planning.typ"          "$OUT/Documentation/Crit_A_Planning.pdf"
typst compile "$REPO_ROOT/doc/Crit_B_Design.typ"            "$OUT/Documentation/Crit_B_Design.pdf"
typst compile "$REPO_ROOT/doc/Crit_B_Record_of_tasks.typ"   "$OUT/Documentation/Crit_B_Record_of_tasks.pdf"
typst compile "$REPO_ROOT/doc/Crit_C_Development.typ"       "$OUT/Documentation/Crit_C_Development.pdf"
typst compile "$REPO_ROOT/doc/Crit_E_Evaluation.typ"        "$OUT/Documentation/Crit_E_Evaluation.pdf"

echo "==> Compiling appendices …"

typst compile "$REPO_ROOT/doc/Appendix_1_Consultation.typ"  "$OUT/Documentation/Appendix_1_Consultation.pdf"
typst compile "$REPO_ROOT/doc/Appendix_2_Feedback.typ"      "$OUT/Documentation/Appendix_2_Feedback.pdf"

if [[ -z "$SKIP_SOURCE_APPENDIX" ]]; then
  echo "==> Building source code appendix …"
  if [[ -x "$REPO_ROOT/scripts/build-source-appendix.sh" ]]; then
    "$REPO_ROOT/scripts/build-source-appendix.sh"
  fi
fi

if [[ -f "$REPO_ROOT/doc/Appendix_3_Source_Code.pdf" ]]; then
  cp "$REPO_ROOT/doc/Appendix_3_Source_Code.pdf"            "$OUT/Documentation/Appendix_3_Source_Code.pdf"
else
  echo "    WARNING: doc/Appendix_3_Source_Code.pdf not found — source-code appendix will be missing from the bundle."
fi

# ── 2. Copy HTML cover page ─────────────────────────────────

echo "==> Copying cover page …"
cp "$REPO_ROOT/doc/cover_page.htm" "$OUT/cover_page.htm"

# ── 3. Copy video into Documentation/ (matches NIck-2 sample) ──

echo "==> Copying video …"

VIDEO_SRC_CANDIDATES=(
  "$REPO_ROOT/doc/Crit_D_Video.mp4"
  "$REPO_ROOT/doc/Crit_D_Functionality.mp4"
  "$REPO_ROOT/doc/Crit_D_Video.m4v"
  "$REPO_ROOT/doc/Crit_D_Video.mov"
)
VIDEO_FOUND=""
for candidate in "${VIDEO_SRC_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VIDEO_FOUND="$candidate"
    break
  fi
done

if [[ -n "$VIDEO_FOUND" ]]; then
  cp "$VIDEO_FOUND" "$OUT/Documentation/Crit_D_Video.mp4"
  echo "    Copied: $(basename "$VIDEO_FOUND") -> Documentation/Crit_D_Video.mp4"
else
  echo "    WARNING: no video found. Expected one of:"
  for c in "${VIDEO_SRC_CANDIDATES[@]}"; do echo "      $c"; done
fi

# ── 4. Assemble Product/ with clean source ──────────────────

echo "==> Assembling Product/ directory …"

PRODUCT="$OUT/Product"
mkdir -p "$PRODUCT"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='.gitignore' \
  --exclude='.github/' \
  --exclude='.claude/' \
  --exclude='.claude-render/' \
  --exclude='.claude-render-hires/' \
  --exclude='.claude-svg-hires/' \
  --exclude='.agents/' \
  --exclude='.playwright-cli/' \
  --exclude='.playwright-mcp/' \
  --exclude='.vscode/' \
  --exclude='.idea/' \
  --exclude='CLAUDE.md' \
  --exclude='Claude.md' \
  --exclude='AGENT.md' \
  --exclude='AGENTS.md' \
  --exclude='SPECS.md' \
  --exclude='RECORDING.md' \
  --exclude='sc-banner-plan.md' \
  --exclude='sc-banner-cues.json' \
  --exclude='fcp-import-guide.md' \
  --exclude='.venv/' \
  --exclude='.ruff_cache/' \
  --exclude='__pycache__/' \
  --exclude='official_doc_sample/' \
  --exclude='target/' \
  --exclude='node_modules/' \
  --exclude='dist/' \
  --exclude='build/' \
  --exclude='.next/' \
  --exclude='DerivedData/' \
  --exclude='output/' \
  --exclude='resource/' \
  --exclude='scripts/' \
  --exclude='ia_guide/' \
  --exclude='*.db' \
  --exclude='*.pdf' \
  --exclude='*.mp4' \
  --exclude='*.mov' \
  --exclude='*.avi' \
  --exclude='*.htm' \
  --exclude='.DS_Store' \
  --exclude='xcuserdata/' \
  --exclude='*.xcuserstate' \
  --exclude='app/' \
  --exclude='design/' \
  --exclude='doc/' \
  --exclude='appendix/' \
  "$REPO_ROOT/" "$PRODUCT/"

# ── 5. Word-count audit (informational) ─────────────────────

echo ""
echo "==> Word-count audit (pdftotext raw, for sanity only) …"
if command -v pdftotext >/dev/null 2>&1; then
  for pdf in "$OUT/Documentation/"Crit_*.pdf; do
    words=$(pdftotext -layout "$pdf" - 2>/dev/null | grep -v "Word Count:" | wc -w | tr -d ' ')
    printf "    %-44s %s words\n" "$(basename "$pdf")" "$words"
  done
fi

# ── 6. Zip the bundle ───────────────────────────────────────

echo ""
echo "==> Creating ZIP …"
(
  cd "$REPO_ROOT/output"
  # -r recursive, -q quiet (still prints a summary), -X no extra mac attrs
  zip -r -q -X "${BUNDLE}.zip" "$BUNDLE"
)

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

# ── 7. Summary ──────────────────────────────────────────────

echo ""
echo "=== Packaging complete ==="
echo ""
echo "Bundle folder: $OUT"
echo "ZIP archive:   $ZIP_PATH  ($ZIP_SIZE)"
echo ""
echo "Structure:"
echo "  $BUNDLE/"
echo "  ├── cover_page.htm"
echo "  ├── Documentation/"
for f in "$OUT/Documentation/"*; do
  printf "  │   ├── %s\n" "$(basename "$f")"
done
echo "  └── Product/ ($(du -sh "$PRODUCT" | cut -f1))"
echo ""
echo "Ready for IB eCoursework upload."
