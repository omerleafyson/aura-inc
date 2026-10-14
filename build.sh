#!/usr/bin/env bash
set -euo pipefail

rm -rf public .aura-build
mkdir -p public/institute_docs .aura-build

MASTER_URL="https://aurainc.floot.app/_cdn/static/c584cada-3a24-4528-a263-5d056c0a10b5-aura-inc-live.txt"
PACK_URLS=(
  "https://aurainc.floot.app/_cdn/static/1e5aba21-621f-4079-bf8a-981b9357f186-iqr_opt_pack_01.zip"
  "https://aurainc.floot.app/_cdn/static/35f92f7c-28cf-4ced-a1b5-8c0c7bc8a230-iqr_opt_pack_02.zip"
  "https://aurainc.floot.app/_cdn/static/c91c395f-5a6b-40ba-ac48-ddb1cc3be02a-iqr_opt_pack_03.zip"
  "https://aurainc.floot.app/_cdn/static/fb851a8e-bc1a-4d4e-a68a-522a14553385-iqr_opt_pack_04.zip"
)

echo "Downloading AURA Inc master HTML..."
curl -fL --retry 4 --retry-delay 2 "$MASTER_URL" -o public/index.html

# The Floot live version routes PDFs through an API endpoint. On Cloudflare we serve
# the optimized PDFs directly as static assets instead.
perl -0pi -e 's#/_api/institute-pdf\?doc=([0-9]{3})#institute_docs/doc_$1.pdf#g' public/index.html

for i in "${!PACK_URLS[@]}"; do
  n=$(printf '%02d' "$((i+1))")
  archive=".aura-build/iqr_opt_pack_${n}.zip"
  echo "Downloading optimized AIQR PDF pack ${n}..."
  curl -fL --retry 4 --retry-delay 2 "${PACK_URLS[$i]}" -o "$archive"
  unzip -q -o -j "$archive" 'doc_*.pdf' -d public/institute_docs
 done

PDF_COUNT=$(find public/institute_docs -type f -name 'doc_*.pdf' | wc -l | tr -d ' ')
if [ "$PDF_COUNT" != "101" ]; then
  echo "ERROR: expected 101 PDFs, found $PDF_COUNT" >&2
  exit 1
fi

# Cloudflare Workers Static Assets has a 25 MiB per-file limit.
TOO_LARGE=$(find public/institute_docs -type f -name 'doc_*.pdf' -size +25M -print -quit)
if [ -n "$TOO_LARGE" ]; then
  echo "ERROR: PDF exceeds Cloudflare 25 MiB asset limit: $TOO_LARGE" >&2
  exit 1
fi

printf 'User-agent: *\nAllow: /\n' > public/robots.txt

echo "AURA Inc production build ready: $PDF_COUNT PDFs"
