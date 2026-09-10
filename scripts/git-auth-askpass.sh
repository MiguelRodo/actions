#!/usr/bin/env bash

setup_git_askpass() {
  if [[ -z "${GIT_TOKEN_FOR_ASKPASS:-}" ]]; then
    echo "Error: GIT_TOKEN_FOR_ASKPASS must be set before configuring Git authentication." >&2
    return 1
  fi

  GIT_ASKPASS_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/git-askpass-XXXXXX")"
  chmod 700 "$GIT_ASKPASS_DIR"
  GIT_ASKPASS_SCRIPT="$GIT_ASKPASS_DIR/askpass.sh"
  cat > "$GIT_ASKPASS_SCRIPT" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  Username\ for\ *) printf '%s\n' "x-access-token" ;;
  Password\ for\ *) printf '%s\n' "$GIT_TOKEN_FOR_ASKPASS" ;;
  *) exit 1 ;;
esac
EOF
  chmod 700 "$GIT_ASKPASS_SCRIPT"

  export GIT_ASKPASS="$GIT_ASKPASS_SCRIPT"
  export GIT_ASKPASS_DIR GIT_ASKPASS_SCRIPT
  export GIT_TERMINAL_PROMPT=0
}

cleanup_git_askpass() {
  if [[ -n "${GIT_ASKPASS_DIR:-}" ]]; then
    rm -rf "$GIT_ASKPASS_DIR"
  fi
  unset GIT_ASKPASS GIT_ASKPASS_DIR GIT_ASKPASS_SCRIPT GIT_TERMINAL_PROMPT GIT_TOKEN_FOR_ASKPASS
}
