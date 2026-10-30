#!/usr/bin/env bash
# Checks the latest upstream Xournal++ release and, if newer, rewrites the
# cask's version and all four sha256 values. Works on macOS and Linux.
# Requires: curl, jq, perl, shasum.
set -euo pipefail

cd "$(dirname "$0")/.."
CASK="Casks/xournalpp.rb"
REPO="xournalpp/xournalpp"

auth=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/${REPO}/releases/latest")"
latest="$(jq -r '.tag_name' <<<"$release_json")"
latest="${latest#v}"
current="$(sed -nE 's/^  version "([^"]+)"$/\1/p' "$CASK")"

echo "current: ${current}  latest: ${latest}"
if [[ "$latest" == "$current" ]]; then
  echo "Up to date."
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
edits=()

# "<cask sha256 key> <upstream asset name>" (no associative arrays: macOS ships bash 3.2)
while read -r key name; do
  url="$(jq -r --arg n "$name" '.assets[] | select(.name == $n) | .browser_download_url' <<<"$release_json")"
  if [[ -z "$url" ]]; then
    echo "ERROR: asset ${name} not found in release v${latest}. Upstream naming may have changed." >&2
    exit 1
  fi
  # GitHub publishes a sha256 digest per release asset; fall back to downloading if absent.
  digest="$(jq -r --arg n "$name" '.assets[] | select(.name == $n) | .digest // empty' <<<"$release_json")"
  if [[ "$digest" == sha256:* ]]; then
    sha="${digest#sha256:}"
  else
    echo "No digest for ${name}, downloading..."
    curl -fsSL -o "${tmp}/${name}" "$url"
    sha="$(shasum -a 256 "${tmp}/${name}" | cut -d' ' -f1)"
  fi
  echo "${key}: ${sha}"
  edits+=("s/(\\b${key}:\\s+\")[0-9a-f]{64}/\${1}${sha}/;")
done <<LIST
arm xournalpp-${latest}-macOS-ARM64.dmg
intel xournalpp-${latest}-macOS-X64.dmg
arm64_linux xournalpp-${latest}-aarch64.AppImage
x86_64_linux xournalpp-${latest}-x86_64.AppImage
LIST

# All assets resolved: only now touch the cask, so a failure never leaves it half-updated.
edits+=("s/^  version \"[^\"]+\"\$/  version \"${latest}\"/;")
perl -pi -e "${edits[*]}" "$CASK"
echo "Updated ${CASK} to ${latest}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=${latest}" >> "$GITHUB_OUTPUT"
fi
