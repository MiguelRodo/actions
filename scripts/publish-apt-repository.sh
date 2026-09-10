#!/usr/bin/env bash

set -euo pipefail

mapfile -d '' DEB_FILES < <(find dist -type f -name '*.deb' -print0 | sort -z)

if [ "${#DEB_FILES[@]}" -eq 0 ]; then
  echo "Error: apt_repo was provided, but no .deb files were found in dist/." >&2
  exit 1
fi

if [[ ! "$APT_REPO_INPUT" =~ ^[^/]+/[^/]+$ ]]; then
  echo "Error: apt_repo must be in owner/name format." >&2
  exit 1
fi

APT_PUSH_TOKEN="${APT_REPO_TOKEN}"
if [ -z "$APT_PUSH_TOKEN" ]; then
  APT_PUSH_TOKEN="${GITHUB_TOKEN_INPUT}"
fi

for REQUIRED_COMMAND in dpkg-deb dpkg-scanpackages apt-ftparchive; do
  if ! command -v "$REQUIRED_COMMAND" >/dev/null 2>&1; then
    echo "Error: required command '$REQUIRED_COMMAND' is not available on the runner." >&2
    exit 1
  fi
done

SIGNING_KEY_FINGERPRINT=""
GNUPGHOME=""
if [ -n "$APT_SIGNING_KEY" ]; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "Error: required command 'gpg' is not available on the runner." >&2
    exit 1
  fi
  # Use an isolated, ephemeral keyring so the key material never touches the
  # default ~/.gnupg and cannot interact with pre-existing keyring state.
  # RUNNER_TEMP is always set on GitHub Actions runners; /tmp is the fallback for local runs.
  GNUPGHOME="$(mktemp -d "${RUNNER_TEMP:-/tmp}/gnupg-XXXXXX")"
  chmod 700 "$GNUPGHOME"
  export GNUPGHOME
  # Extract the fingerprint using a dry-run import (--import-options show-only).
  # The `{ ... } 3>&2` pattern routes GPG's stderr to the terminal (fd 2) while
  # command substitution only captures stdout for fingerprint parsing.
  { SIGNING_KEY_FINGERPRINT="$(printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --with-colons --import-options show-only --import 2>&3 | awk -F: '/^fpr:/ { print $10; exit }')"; } 3>&2
  if [ -z "$SIGNING_KEY_FINGERPRINT" ]; then
    echo "Error: could not extract fingerprint from apt_signing_key; ensure it is a valid ASCII-armored GPG private key." >&2
    exit 1
  fi
  if ! printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --import; then
    echo "Error: failed to import apt_signing_key into the GPG keyring." >&2
    exit 1
  fi
fi

APT_REPO_OWNER="${APT_REPO_INPUT%%/*}"
APT_REPO_NAME="${APT_REPO_INPUT##*/}"

APT_REPO_DIR=""
GPG_PASSPHRASE_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/git-auth-askpass.sh
source "$SCRIPT_DIR/git-auth-askpass.sh"
cleanup() {
  if [ -n "$APT_REPO_DIR" ]; then
    rm -rf "$APT_REPO_DIR"
  fi

  cleanup_git_askpass

  if [ -n "$GNUPGHOME" ]; then
    rm -rf "$GNUPGHOME"
  fi

  if [ -n "$GPG_PASSPHRASE_FILE" ]; then
    rm -f "$GPG_PASSPHRASE_FILE"
  fi
}
trap cleanup EXIT

APT_REPO_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/apt-repo-XXXXXX")"
export GIT_TOKEN_FOR_ASKPASS="$APT_PUSH_TOKEN"
setup_git_askpass

git clone \
  --branch main \
  --single-branch \
  "${GITHUB_SERVER_URL}/${APT_REPO_INPUT}.git" \
  "$APT_REPO_DIR"

declare -A ARCH_SEEN=()
publish_deb() {
  local SOURCE_DEB="$1"
  local COPY_MODE="$2"
  local PACKAGE_NAME
  local PACKAGE_ARCH
  local BUCKET
  local DEST_DIR
  local DEST_FILE

  PACKAGE_NAME="$(dpkg-deb -f "$SOURCE_DEB" Package | tr -d '\n')"
  PACKAGE_ARCH="$(dpkg-deb -f "$SOURCE_DEB" Architecture | tr -d '\n')"

  if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: could not determine package name from $SOURCE_DEB." >&2
    exit 1
  fi

  if [ -z "$PACKAGE_ARCH" ]; then
    echo "Error: could not determine package architecture from $SOURCE_DEB." >&2
    exit 1
  fi

  BUCKET="$(printf '%s' "$PACKAGE_NAME" | cut -c1 | tr '[:upper:]' '[:lower:]')"
  if [[ ! "$BUCKET" =~ ^[a-z0-9]$ ]]; then
    BUCKET="_"
  fi

  DEST_DIR="$APT_REPO_DIR/pool/main/$BUCKET"
  DEST_FILE="$DEST_DIR/$(basename "$SOURCE_DEB")"
  mkdir -p "$DEST_DIR"

  if [ "$COPY_MODE" = "move" ]; then
    if [ "$SOURCE_DEB" != "$DEST_FILE" ]; then
      mv -f "$SOURCE_DEB" "$DEST_FILE"
    fi
  else
    cp -f "$SOURCE_DEB" "$DEST_FILE"
  fi

  ARCH_SEEN["$PACKAGE_ARCH"]=1
}

mapfile -d '' EXISTING_DEB_FILES < <(find "$APT_REPO_DIR" \( -path "$APT_REPO_DIR/.git" -prune \) -o \( -type f -name '*.deb' -print0 \) | sort -z)
for EXISTING_DEB_FILE in "${EXISTING_DEB_FILES[@]}"; do
  publish_deb "$EXISTING_DEB_FILE" "move"
done

for DEB_FILE in "${DEB_FILES[@]}"; do
  publish_deb "$DEB_FILE" "copy"
done

mapfile -t PUBLISHED_ARCHES < <(printf '%s\n' "${!ARCH_SEEN[@]}" | sort -u)
if [ "${#PUBLISHED_ARCHES[@]}" -eq 0 ]; then
  echo "Error: no package architectures were detected while publishing apt repository contents." >&2
  exit 1
fi

(
  cd "$APT_REPO_DIR"

  rm -rf dists/stable/main/binary-*
  mkdir -p dists/stable/main

  for ARCH in "${PUBLISHED_ARCHES[@]}"; do
    BINARY_DIR="dists/stable/main/binary-${ARCH}"
    mkdir -p "$BINARY_DIR"
    dpkg-scanpackages --multiversion -a "$ARCH" pool /dev/null > "$BINARY_DIR/Packages"
    gzip -9c "$BINARY_DIR/Packages" > "$BINARY_DIR/Packages.gz"
  done

  ARCH_LIST="$(printf '%s ' "${PUBLISHED_ARCHES[@]}")"
  ARCH_LIST="${ARCH_LIST% }"
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="$APT_REPO_OWNER" \
    -o APT::FTPArchive::Release::Label="$APT_REPO_NAME" \
    -o APT::FTPArchive::Release::Suite="stable" \
    -o APT::FTPArchive::Release::Codename="stable" \
    -o APT::FTPArchive::Release::Architectures="$ARCH_LIST" \
    -o APT::FTPArchive::Release::Components="main" \
    release dists/stable > dists/stable/Release

  rm -f Packages Packages.gz Release

  if [ -n "$SIGNING_KEY_FINGERPRINT" ]; then
    GPG_SIGN_OPTS=(--batch --yes --pinentry-mode loopback --default-key "$SIGNING_KEY_FINGERPRINT")
    if [ -n "$APT_SIGNING_KEY_PASSPHRASE" ]; then
      # Write the passphrase to a mode-600 temp file so GPG can read it via
      # --passphrase-file without exposing it on the command line or via stdin,
      # which can mis-handle passphrases containing special characters.
      # RUNNER_TEMP is set by GitHub Actions; /tmp is the fallback for local runs.
      GPG_PASSPHRASE_FILE="$(mktemp "${RUNNER_TEMP:-/tmp}/gpg-passphrase-XXXXXX")"
      chmod 600 "$GPG_PASSPHRASE_FILE"
      printf '%s' "$APT_SIGNING_KEY_PASSPHRASE" > "$GPG_PASSPHRASE_FILE"
      GPG_SIGN_OPTS+=(--passphrase-file "$GPG_PASSPHRASE_FILE")
    fi
    gpg "${GPG_SIGN_OPTS[@]}" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
    gpg "${GPG_SIGN_OPTS[@]}" --clearsign -o dists/stable/InRelease dists/stable/Release
  else
    # Remove stale signed metadata because no signing key was configured.
    rm -f InRelease Release.gpg dists/stable/InRelease dists/stable/Release.gpg
  fi

  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  git add -A

  if git diff --cached --quiet; then
    echo "No apt repository changes to publish."
    exit 0
  fi

  git commit -m "Publish Debian packages for $TAG"
  git push origin HEAD:main
)
