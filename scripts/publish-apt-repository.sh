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

APT_REPO_OWNER="${APT_REPO_INPUT%%/*}"
APT_REPO_NAME="${APT_REPO_INPUT##*/}"
APT_REPO_DIR=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/git-auth-askpass.sh
source "$SCRIPT_DIR/git-auth-askpass.sh"
# shellcheck source=scripts/apt-repository-metadata.sh
source "$SCRIPT_DIR/apt-repository-metadata.sh"

cleanup() {
  if [ -n "$APT_REPO_DIR" ]; then
    rm -rf "$APT_REPO_DIR"
  fi
  cleanup_git_askpass
  apt_repository_cleanup_signing
}
trap cleanup EXIT

apt_repository_require_tools
apt_repository_setup_signing

APT_REPO_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/apt-repo-XXXXXX")"
export GIT_TOKEN_FOR_ASKPASS="$APT_PUSH_TOKEN"
setup_git_askpass

git clone \
  --branch main \
  --single-branch \
  "${GITHUB_SERVER_URL}/${APT_REPO_INPUT}.git" \
  "$APT_REPO_DIR"

publish_deb() {
  local source_deb="$1"
  local copy_mode="$2"
  local package_name
  local package_arch
  local bucket
  local dest_dir
  local dest_file

  package_name="$(dpkg-deb -f "$source_deb" Package | tr -d '\n')"
  package_arch="$(dpkg-deb -f "$source_deb" Architecture | tr -d '\n')"

  if [ -z "$package_name" ]; then
    echo "Error: could not determine package name from $source_deb." >&2
    exit 1
  fi

  if [ -z "$package_arch" ]; then
    echo "Error: could not determine package architecture from $source_deb." >&2
    exit 1
  fi

  bucket="$(printf '%s' "$package_name" | cut -c1 | tr '[:upper:]' '[:lower:]')"
  if [[ ! "$bucket" =~ ^[a-z0-9]$ ]]; then
    bucket="_"
  fi

  dest_dir="$APT_REPO_DIR/pool/main/$bucket"
  dest_file="$dest_dir/$(basename "$source_deb")"
  mkdir -p "$dest_dir"

  if [ "$copy_mode" = "move" ]; then
    if [ "$source_deb" != "$dest_file" ]; then
      mv -f "$source_deb" "$dest_file"
    fi
  else
    cp -f "$source_deb" "$dest_file"
  fi
}

mapfile -d '' EXISTING_DEB_FILES < <(find "$APT_REPO_DIR" \( -path "$APT_REPO_DIR/.git" -prune \) -o \( -type f -name '*.deb' -print0 \) | sort -z)
for EXISTING_DEB_FILE in "${EXISTING_DEB_FILES[@]}"; do
  publish_deb "$EXISTING_DEB_FILE" "move"
done

for DEB_FILE in "${DEB_FILES[@]}"; do
  publish_deb "$DEB_FILE" "copy"
done

apt_repository_regenerate_metadata "$APT_REPO_DIR" "$APT_REPO_OWNER" "$APT_REPO_NAME"

(
  cd "$APT_REPO_DIR"
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
