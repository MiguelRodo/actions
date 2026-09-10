## Finding identity and pull request deduplication

Before opening a remediation pull request:

1. Pipe the exact vulnerable hunk to `scripts/sentinel-fingerprint.sh fingerprint OWNER/REPOSITORY PATH VULNERABILITY_CLASS SCOPE`.
2. Put the emitted HTML comment in the pull request body unchanged.
3. Search open pull requests for the complete `sentinel-fingerprint:` value. Reuse or update an existing remediation instead of creating another.
4. Create one remediation pull request per fingerprint.

The hunk's SHA-256 hash makes unchanged findings stable while allowing genuinely changed vulnerable code to receive a new identity. The `Deduplicate Sentinel remediation PRs` workflow retains the oldest owner-authored open PR for an identity and closes newer duplicates. Its manual `dry_run` mode identifies duplicates without changing them.

## 2024-05-22 - [Insecure GitHub Auth Token Usage]
**Vulnerability:** `gh auth login --with-token <<< "$GH_TOKEN"` logs the token authentication, but native `GH_TOKEN` environment variable is more secure and doesn't expose the token. Wait, actually `gh` natively supports `GH_TOKEN` so `gh auth login` is unneeded. The `git clone` steps later use `git config --global credential.helper store` and `echo "https://x-access-token:${GH_TOKEN}@github.com" > ~/.git-credentials` which exposes token in file on runner.
**Learning:** Using `gh auth login` with `<<<` or `echo` might expose token in system logs or history. Storing token in `~/.git-credentials` on shared runner could lead to token leakage if the runner is not cleaned up or another process reads it. The memory says: "Never echo authentication tokens or credentials (e.g., `echo "$TOKEN" | gh auth login`) in GitHub Actions workflows to prevent data exposure in logs. Instead, use the `GH_TOKEN` environment variable natively supported by the GitHub CLI, mapping it directly from action inputs in the step's env block."
**Prevention:** Remove `gh auth login` and `~/.git-credentials`. Use `GH_TOKEN` directly for `gh` commands. For authenticated Git operations, use a temporary `GIT_ASKPASS` helper with restrictive permissions, keep the remote URL token-free, and remove the helper with an `EXIT` trap.
## 2024-05-23 - [Insecure authenticated remote URL mapping]
**Vulnerability:** A script was parsing a token from input and building an authenticated Git remote URL manually using `AUTHENTICATED_REMOTE="${SERVER_URL/https:\/\//https:\/\/x-access-token:${PUSH_TOKEN}@}/${REPO_INPUT}.git"`, and subsequently doing `git remote add origin "$AUTHENTICATED_REMOTE"`.
**Learning:** Adding the remote with the token embedded directly writes the token in plain text to `.git/config` on disk inside the runner. This causes credentials to be leaked in case `.git/` folder gets cached, exposed or read by another step.
**Prevention:** Do not inject tokens into remote URLs or global URL rewrites, because both persist credentials on disk. Use a temporary `GIT_ASKPASS` helper backed by an environment variable, use the normal HTTPS remote URL, and clean up the helper and environment variables on every exit path.
