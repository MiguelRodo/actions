#!/usr/bin/env bats

ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/apt-prune-regenerate-metadata.sh"

setup() {
  REPO_DIR="$BATS_TEST_TMPDIR/repo with spaces"
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$REPO_DIR/pool/main/d" "$MOCK_BIN"

  cat > "$MOCK_BIN/dpkg-deb" <<'EOF'
#!/usr/bin/env bash
base="$(basename "$2" .deb)"
arch="${base##*_}"
case "$3" in
  Architecture) printf '%s\n' "$arch" ;;
  *) exit 1 ;;
esac
EOF

  cat > "$MOCK_BIN/dpkg-scanpackages" <<'EOF'
#!/usr/bin/env bash
arch=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-a" ]; then
    arch="$2"
    shift 2
  else
    shift
  fi
done
printf 'Package: demo\nArchitecture: %s\n' "$arch"
EOF

  cat > "$MOCK_BIN/apt-ftparchive" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*"
EOF

  chmod +x "$MOCK_BIN"/*
  export PATH="$MOCK_BIN:$PATH"
}

@test "apt prune regenerates unsigned metadata for every remaining architecture" {
  touch "$REPO_DIR/pool/main/d/demo_1.0.0_amd64.deb"
  touch "$REPO_DIR/pool/main/d/demo_1.0.0_arm64.deb"
  mkdir -p "$REPO_DIR/dists/stable/main/binary-old"
  touch "$REPO_DIR/dists/stable/main/binary-old/Packages"
  touch "$REPO_DIR/Packages" "$REPO_DIR/Packages.gz" "$REPO_DIR/Release"
  touch "$REPO_DIR/dists/stable/InRelease" "$REPO_DIR/dists/stable/Release.gpg"

  run bash "$SCRIPT" "$REPO_DIR" "owner/packages"
  [ "$status" -eq 0 ]

  for arch in amd64 arm64; do
    [ -f "$REPO_DIR/dists/stable/main/binary-$arch/Packages" ]
    [ -f "$REPO_DIR/dists/stable/main/binary-$arch/Packages.gz" ]
    run grep -F "Architecture: $arch" "$REPO_DIR/dists/stable/main/binary-$arch/Packages"
    [ "$status" -eq 0 ]
  done

  [ ! -d "$REPO_DIR/dists/stable/main/binary-old" ]
  [ -f "$REPO_DIR/dists/stable/Release" ]
  run grep -F 'APT::FTPArchive::Release::Origin=owner' "$REPO_DIR/dists/stable/Release"
  [ "$status" -eq 0 ]
  run grep -F 'APT::FTPArchive::Release::Label=packages' "$REPO_DIR/dists/stable/Release"
  [ "$status" -eq 0 ]
  run grep -F 'APT::FTPArchive::Release::Architectures=amd64 arm64' "$REPO_DIR/dists/stable/Release"
  [ "$status" -eq 0 ]

  [ ! -e "$REPO_DIR/Packages" ]
  [ ! -e "$REPO_DIR/Packages.gz" ]
  [ ! -e "$REPO_DIR/Release" ]
  [ ! -e "$REPO_DIR/dists/stable/InRelease" ]
  [ ! -e "$REPO_DIR/dists/stable/Release.gpg" ]
}

@test "apt prune clears metadata when no Debian packages remain" {
  mkdir -p "$REPO_DIR/dists/stable/main/binary-amd64"
  touch "$REPO_DIR/dists/stable/main/binary-amd64/Packages"
  touch "$REPO_DIR/dists/stable/main/binary-amd64/Packages.gz"
  touch "$REPO_DIR/dists/stable/Release"
  touch "$REPO_DIR/dists/stable/InRelease" "$REPO_DIR/dists/stable/Release.gpg"

  run bash "$SCRIPT" "$REPO_DIR" "owner/packages"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no .deb files remain after pruning"* ]]

  [ ! -d "$REPO_DIR/dists/stable/main/binary-amd64" ]
  [ ! -e "$REPO_DIR/dists/stable/Release" ]
  [ ! -e "$REPO_DIR/dists/stable/InRelease" ]
  [ ! -e "$REPO_DIR/dists/stable/Release.gpg" ]
}
