#!/usr/bin/env bash
#
# update-pw-silhouettes.sh
#
# Pulls the latest release of plane-watch/pw-silhouettes (spritesheet.png +
# spritesheet.json) and installs it into ./pw-silhouettes/, next to index.html.
#
# WHY THIS IS A SEPARATE SCRIPT AND NOT DONE IN THE BROWSER:
# GitHub does not send Access-Control-Allow-Origin headers on release assets
# (neither on the github.com/.../releases/download/... redirect nor on the
# release-assets.githubusercontent.com host it redirects to), so a browser
# fetch() for these files is blocked by CORS no matter how it's written.
# Running from a shell sidesteps that entirely - curl isn't subject to CORS,
# only browsers enforce it.
#
# USAGE:
#   Primary: run inside .github/workflows/update-pw-silhouettes.yml, which
#   invokes this on GitHub's own runner and commits the result back into the
#   repo - that's what makes GitHub Pages pick up the refreshed sheet.
#
#   Also runnable by hand (e.g. locally, right after cloning) or from your own
#   cron if you're hosting this somewhere other than Pages:
#     ./update-pw-silhouettes.sh [/path/to/site/dir]
#       (defaults to the directory this script lives in)
#
# Requires: curl, python3 (both present by default on Raspberry Pi OS).
# Exits non-zero on any failure and leaves the existing spritesheet in place
# untouched - a failed refresh should never take the radar display down.

set -euo pipefail

REPO="plane-watch/pw-silhouettes"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

SITE_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
DEST_DIR="${SITE_DIR}/pw-silhouettes"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "[update-pw-silhouettes] checking ${REPO} latest release..."

RELEASE_JSON="${TMP_DIR}/release.json"
# -f: fail (non-zero exit) on HTTP errors instead of writing the error page to the file
if ! curl -fsSL -H "Accept: application/vnd.github+json" "${API_URL}" -o "${RELEASE_JSON}"; then
  echo "[update-pw-silhouettes] ERROR: failed to reach ${API_URL} (offline? rate-limited? - unauthenticated GitHub API calls are capped at 60/hour per IP)" >&2
  exit 1
fi

# Pull out the browser_download_url for the two named assets. Done with python3's
# json module rather than grep/sed so it can't be tripped up by field ordering or
# by another asset's name/URL appearing elsewhere in the payload.
PNG_URL="$(python3 -c "
import json, sys
with open('${RELEASE_JSON}') as f:
    release = json.load(f)
for asset in release.get('assets', []):
    if asset.get('name') == 'spritesheet.png':
        print(asset['browser_download_url'])
        break
")"
JSON_URL="$(python3 -c "
import json, sys
with open('${RELEASE_JSON}') as f:
    release = json.load(f)
for asset in release.get('assets', []):
    if asset.get('name') == 'spritesheet.json':
        print(asset['browser_download_url'])
        break
")"
RELEASE_TAG="$(python3 -c "
import json
with open('${RELEASE_JSON}') as f:
    print(json.load(f).get('tag_name', 'unknown'))
")"

if [ -z "${PNG_URL}" ] || [ -z "${JSON_URL}" ]; then
  echo "[update-pw-silhouettes] ERROR: latest release (${RELEASE_TAG}) doesn't have both spritesheet.png and spritesheet.json attached - leaving the existing local copy untouched" >&2
  exit 1
fi

echo "[update-pw-silhouettes] latest release is ${RELEASE_TAG} - downloading..."
curl -fsSL "${PNG_URL}" -o "${TMP_DIR}/spritesheet.png"
curl -fsSL "${JSON_URL}" -o "${TMP_DIR}/spritesheet.json"

# Sanity-check the JSON actually parses and the PNG actually has PNG magic bytes
# before we let either overwrite the working copy.
python3 -c "import json; json.load(open('${TMP_DIR}/spritesheet.json'))"
if [ "$(head -c 8 "${TMP_DIR}/spritesheet.png" | od -An -tx1 | tr -d ' \n')" != "89504e470d0a1a0a" ]; then
  echo "[update-pw-silhouettes] ERROR: downloaded spritesheet.png doesn't look like a valid PNG - aborting" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
# Move into place last, after both files are downloaded and validated, so a
# refresh is all-or-nothing - the page is never left pointing at a half-updated pair.
mv "${TMP_DIR}/spritesheet.png" "${DEST_DIR}/spritesheet.png"
mv "${TMP_DIR}/spritesheet.json" "${DEST_DIR}/spritesheet.json"

echo "[update-pw-silhouettes] done - ${DEST_DIR} now on release ${RELEASE_TAG}"
