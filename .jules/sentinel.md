## 2024-05-16 - Prevent Shell Injection in GitHub Actions
**Vulnerability:** User-controlled inputs (`${{ inputs.something }}`) were directly interpolated into bash scripts (`run:` blocks) in GitHub Actions, which can lead to shell injection vulnerabilities.
**Learning:** GitHub Actions evaluate `${{ ... }}` expressions before running the script. If an input contains bash metacharacters (e.g. `'; r m - r f /; '`), it gets injected directly into the script content.
**Prevention:** Always pass GitHub Actions inputs or variables to bash scripts via the `env:` context instead of direct interpolation, and reference them in the script as standard environment variables (`$ENV_VAR`).
