#!/usr/bin/env bash

apt_repository_require_tools() {
  local command_name
  for command_name in dpkg-deb dpkg-scanpackages apt-ftparchive; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "Error: required command '$command_name' is not available on the runner." >&2
      return 1
    fi
  done
}

apt_repository_setup_signing() {
  SIGNING_KEY_FINGERPRINT=""
  GNUPGHOME=""
  GPG_PASSPHRASE_FILE=""

  if [[ -z "${APT_SIGNING_KEY:-}" ]]; then
    return 0
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    echo "Error: required command 'gpg' is not available on the runner." >&2
    return 1
  fi

  GNUPGHOME="$(mktemp -d "${RUNNER_TEMP:-/tmp}/gnupg-XXXXXX")"
  chmod 700 "$GNUPGHOME"
  export GNUPGHOME

  { SIGNING_KEY_FINGERPRINT="$(printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --with-colons --import-options show-only --import 2>&3 | awk -F: '/^fpr:/ { print $10; exit }')"; } 3>&2
  if [[ -z "$SIGNING_KEY_FINGERPRINT" ]]; then
    echo "Error: could not extract fingerprint from apt_signing_key; ensure it is a valid ASCII-armored GPG private key." >&2
    return 1
  fi

  if ! printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --import; then
    echo "Error: failed to import apt_signing_key into the GPG keyring." >&2
    return 1
  fi

  if [[ -n "${APT_SIGNING_KEY_PASSPHRASE:-}" ]]; then
    GPG_PASSPHRASE_FILE="$(mktemp "${RUNNER_TEMP:-/tmp}/gpg-passphrase-XXXXXX")"
    chmod 600 "$GPG_PASSPHRASE_FILE"
    printf '%s' "$APT_SIGNING_KEY_PASSPHRASE" > "$GPG_PASSPHRASE_FILE"
  fi
}

apt_repository_cleanup_signing() {
  if [[ -n "${GNUPGHOME:-}" ]]; then
    rm -rf "$GNUPGHOME"
  fi
  if [[ -n "${GPG_PASSPHRASE_FILE:-}" ]]; then
    rm -f "$GPG_PASSPHRASE_FILE"
  fi
  unset GNUPGHOME GPG_PASSPHRASE_FILE SIGNING_KEY_FINGERPRINT
}

apt_repository_regenerate_metadata() {
  local repo_dir="$1"
  local repo_owner="$2"
  local repo_name="$3"
  local empty_policy="${4:-error}"

  (
    cd "$repo_dir"

    declare -A arch_seen=()
    local deb_file
    local package_arch
    while IFS= read -r -d '' deb_file; do
      package_arch="$(dpkg-deb -f "$deb_file" Architecture 2>/dev/null | tr -d '\n')" || continue
      [[ -n "$package_arch" ]] && arch_seen["$package_arch"]=1
    done < <(find pool -type f -name '*.deb' -print0 2>/dev/null | sort -z)

    rm -rf dists/stable/main/binary-*
    mkdir -p dists/stable/main

    if [[ "${#arch_seen[@]}" -eq 0 ]]; then
      if [[ "$empty_policy" != "clear" ]]; then
        echo "Error: no package architectures were detected while publishing apt repository contents." >&2
        return 1
      fi

      echo "Warning: no .deb files remain after pruning; clearing apt metadata." >&2
      rm -f dists/stable/Release dists/stable/InRelease dists/stable/Release.gpg
      rm -f Packages Packages.gz Release InRelease Release.gpg
      return 0
    fi

    local -a sorted_arches
    mapfile -t sorted_arches < <(printf '%s\n' "${!arch_seen[@]}" | sort)

    local arch
    local binary_dir
    for arch in "${sorted_arches[@]}"; do
      binary_dir="dists/stable/main/binary-${arch}"
      mkdir -p "$binary_dir"
      dpkg-scanpackages --multiversion -a "$arch" pool /dev/null > "$binary_dir/Packages"
      gzip -9c "$binary_dir/Packages" > "$binary_dir/Packages.gz"
    done

    local arch_list
    arch_list="$(printf '%s ' "${sorted_arches[@]}")"
    arch_list="${arch_list% }"
    apt-ftparchive \
      -o APT::FTPArchive::Release::Origin="$repo_owner" \
      -o APT::FTPArchive::Release::Label="$repo_name" \
      -o APT::FTPArchive::Release::Suite="stable" \
      -o APT::FTPArchive::Release::Codename="stable" \
      -o APT::FTPArchive::Release::Architectures="$arch_list" \
      -o APT::FTPArchive::Release::Components="main" \
      release dists/stable > dists/stable/Release

    rm -f Packages Packages.gz Release

    if [[ -n "${SIGNING_KEY_FINGERPRINT:-}" ]]; then
      local -a gpg_sign_opts=(--batch --yes --pinentry-mode loopback --default-key "$SIGNING_KEY_FINGERPRINT")
      if [[ -n "${GPG_PASSPHRASE_FILE:-}" ]]; then
        gpg_sign_opts+=(--passphrase-file "$GPG_PASSPHRASE_FILE")
      fi
      gpg "${gpg_sign_opts[@]}" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
      gpg "${gpg_sign_opts[@]}" --clearsign -o dists/stable/InRelease dists/stable/Release
    else
      rm -f InRelease Release.gpg dists/stable/InRelease dists/stable/Release.gpg
    fi
  )
}
