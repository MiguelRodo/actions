#!/bin/bash
# apt-prune-select-versions.sh
#
# Reads .deb files under <repo-dir>/pool and writes to stdout the relative
# paths (from <repo-dir>) of files that should be REMOVED based on the
# chosen retention policy.
#
# Usage: apt-prune-select-versions.sh <retention> <repo-dir>
#
#   retention  One of (case-insensitive):
#              latest            – keep only the newest version per (package, arch) pair
#              latest-per-minor  – keep the highest patch for each major.minor per (package, arch)
#              latest-per-major  – keep the highest minor.patch for each major per (package, arch)
#   repo-dir   Root of the apt repository (the pool/ subdirectory is searched).
#
# The script exits 0 in all normal cases and prints nothing when there is
# nothing to remove.

set -euo pipefail

RETENTION="${1:?Usage: apt-prune-select-versions.sh <retention> <repo-dir>}"
REPO_DIR="${2:?Usage: apt-prune-select-versions.sh <retention> <repo-dir>}"

# Normalize to lowercase so the argument is case-agnostic.
RETENTION="${RETENTION,,}"

case "$RETENTION" in
  latest | latest-per-minor | latest-per-major) ;;
  *)
    echo "Error: retention must be one of: latest, latest-per-minor, latest-per-major." >&2
    exit 1
    ;;
esac

# ── Build package inventory ──────────────────────────────────────────────────
# Each line: <pkg>\t<version>\t<upstream-version>\t<arch>\t<relpath>
TMP_DATA="$(mktemp)"
cleanup() {
  rm -f "$TMP_DATA"
}
trap cleanup EXIT

while IFS= read -r -d '' FILE; do
  # Make path relative to repo root
  REL_PATH="${FILE#"${REPO_DIR}/"}"

  PKG="$(dpkg-deb -f "$FILE" Package 2>/dev/null | tr -d '\n')" || continue
  VER="$(dpkg-deb -f "$FILE" Version 2>/dev/null | tr -d '\n')" || continue
  ARCH="$(dpkg-deb -f "$FILE" Architecture 2>/dev/null | tr -d '\n')" || continue

  [ -n "$PKG" ]  || continue
  [ -n "$VER" ]  || continue
  [ -n "$ARCH" ] || continue

  # Strip epoch but retain the Debian revision so 1.0.0-2 sorts after 1.0.0-1.
  VER="${VER##*:}"
  VER="${VER#v}"
  UPSTREAM_VER="${VER%%-*}"

  # Handle semver X.Y.Z with an optional Debian revision.
  [[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.+~]+)?$ ]] || continue

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$PKG" "$VER" "$UPSTREAM_VER" "$ARCH" "$REL_PATH" >> "$TMP_DATA"
done < <(find "${REPO_DIR}/pool" -type f -name '*.deb' -print0 2>/dev/null | sort -z)

[ -s "$TMP_DATA" ] || exit 0

# ── Process each (pkg, arch) group ──────────────────────────────────────────

# GNU sort -V does not implement Debian's version ordering for all valid
# revisions, so compare package versions with dpkg itself.
version_is_newer() {
  dpkg --compare-versions "$1" gt "$2"
}

while IFS=$'\t' read -r COMBO_PKG COMBO_ARCH; do
  mapfile -t VERSIONS < <(
    awk -F'\t' -v p="$COMBO_PKG" -v a="$COMBO_ARCH" \
      '$1==p && $4==a { print $2 }' "$TMP_DATA" | sort -u
  )

  [ "${#VERSIONS[@]}" -eq 0 ] && continue

  # Determine which versions to keep using Debian's comparison algorithm.
  declare -a _KEEP=()
  declare -A _BEST_BY_SERIES=()
  for V in "${VERSIONS[@]}"; do
    UPSTREAM_VER="${V%%-*}"
    case "$RETENTION" in
      latest)
        SERIES_KEY="all"
        ;;
      latest-per-minor)
        SERIES_KEY="${UPSTREAM_VER%.*}"
        ;;
      latest-per-major)
        SERIES_KEY="${UPSTREAM_VER%%.*}"
        ;;
    esac

    CURRENT_BEST="${_BEST_BY_SERIES["$SERIES_KEY"]-}"
    if [[ -z "$CURRENT_BEST" ]] || version_is_newer "$V" "$CURRENT_BEST"; then
      _BEST_BY_SERIES["$SERIES_KEY"]="$V"
    fi
  done
  _KEEP=("${_BEST_BY_SERIES[@]}")
  unset _BEST_BY_SERIES

  # Build a quick-lookup set of kept versions
  declare -A _KEEP_SET=()
  for V in "${_KEEP[@]}"; do
    _KEEP_SET["$V"]=1
  done

  # Output paths of files whose version is NOT in the keep-set
  while IFS=$'\t' read -r _P _V _UPSTREAM _A _PATH; do
    [ "$_P" = "$COMBO_PKG" ]  || continue
    [ "$_A" = "$COMBO_ARCH" ] || continue
    if [ -z "${_KEEP_SET["$_V"]+x}" ]; then
      printf '%s\n' "$_PATH"
    fi
  done < "$TMP_DATA"

  unset _KEEP _KEEP_SET

done < <(awk -F'\t' '{ print $1 "\t" $4 }' "$TMP_DATA" | sort -u)
