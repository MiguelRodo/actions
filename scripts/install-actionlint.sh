#!/usr/bin/env bash
# Install the repository-pinned actionlint release after verifying its upstream
# published SHA-256 checksum.

set -euo pipefail

readonly ACTIONLINT_VERSION="1.7.12"
readonly ARCHIVE="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
readonly EXPECTED_SHA256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
readonly DOWNLOAD_URL="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${ARCHIVE}"
readonly OUTPUT_PATH="${1:-actionlint}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl --fail --silent --show-error --location \
  --proto '=https' --tlsv1.2 \
  --output "$tmpdir/$ARCHIVE" \
  "$DOWNLOAD_URL"

printf '%s  %s\n' "$EXPECTED_SHA256" "$tmpdir/$ARCHIVE" | sha256sum --check --status

tar -xzf "$tmpdir/$ARCHIVE" -C "$tmpdir" actionlint
install -m 0755 "$tmpdir/actionlint" "$OUTPUT_PATH"

"$OUTPUT_PATH" --version
