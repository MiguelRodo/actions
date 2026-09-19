#!/usr/bin/env bash
set -euo pipefail

repo_dir="${1:?Usage: apt-prune-regenerate-metadata.sh <repo-dir> <owner/repo> [signing-fingerprint] [passphrase-file]}"
repo_input="${2:?Usage: apt-prune-regenerate-metadata.sh <repo-dir> <owner/repo> [signing-fingerprint] [passphrase-file]}"
signing_fingerprint="${3:-}"
passphrase_file="${4:-}"

repo_owner="${repo_input%%/*}"
repo_name="${repo_input##*/}"

declare -A arch_seen=()
while IFS= read -r -d '' deb_file; do
  pkg_arch="$(dpkg-deb -f "$deb_file" Architecture 2>/dev/null | tr -d '\n')" || continue
  [ -n "$pkg_arch" ] && arch_seen["$pkg_arch"]=1
done < <(find "$repo_dir/pool" -type f -name '*.deb' -print0 2>/dev/null | sort -z)

rm -rf "$repo_dir"/dists/stable/main/binary-*
mkdir -p "$repo_dir/dists/stable/main"

if [ "${#arch_seen[@]}" -gt 0 ]; then
  mapfile -t sorted_arches < <(printf '%s\n' "${!arch_seen[@]}" | sort)
  for arch in "${sorted_arches[@]}"; do
    binary_dir="$repo_dir/dists/stable/main/binary-${arch}"
    mkdir -p "$binary_dir"
    (
      cd "$repo_dir"
      dpkg-scanpackages --multiversion -a "$arch" pool /dev/null > "dists/stable/main/binary-${arch}/Packages"
      gzip -9c "dists/stable/main/binary-${arch}/Packages" > "dists/stable/main/binary-${arch}/Packages.gz"
    )
  done

  arch_list="$(printf '%s ' "${sorted_arches[@]}")"
  arch_list="${arch_list% }"
  (
    cd "$repo_dir"
    apt-ftparchive \
      -o APT::FTPArchive::Release::Origin="$repo_owner" \
      -o APT::FTPArchive::Release::Label="$repo_name" \
      -o APT::FTPArchive::Release::Suite="stable" \
      -o APT::FTPArchive::Release::Codename="stable" \
      -o APT::FTPArchive::Release::Architectures="$arch_list" \
      -o APT::FTPArchive::Release::Components="main" \
      release dists/stable > dists/stable/Release
  )
else
  echo "Warning: no .deb files remain after pruning; clearing apt metadata." >&2
  rm -f "$repo_dir"/dists/stable/main/*/Packages "$repo_dir"/dists/stable/main/*/Packages.gz
  rm -f "$repo_dir/dists/stable/Release"
fi

rm -f "$repo_dir/Packages" "$repo_dir/Packages.gz" "$repo_dir/Release"

if [ -n "$signing_fingerprint" ]; then
  gpg_sign_opts=(--batch --yes --pinentry-mode loopback --default-key "$signing_fingerprint")
  if [ -n "$passphrase_file" ]; then
    gpg_sign_opts+=(--passphrase-file "$passphrase_file")
  fi
  gpg "${gpg_sign_opts[@]}" --armor --detach-sign \
    -o "$repo_dir/dists/stable/Release.gpg" "$repo_dir/dists/stable/Release"
  gpg "${gpg_sign_opts[@]}" --clearsign \
    -o "$repo_dir/dists/stable/InRelease" "$repo_dir/dists/stable/Release"
else
  rm -f "$repo_dir/InRelease" "$repo_dir/Release.gpg" \
    "$repo_dir/dists/stable/InRelease" "$repo_dir/dists/stable/Release.gpg"
fi
