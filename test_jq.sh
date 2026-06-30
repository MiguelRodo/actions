RENV_PKGS_INPUT="pkg1;pkg2"
PKGS_ARRAY=$(echo -n "$RENV_PKGS_INPUT" | jq -R -s -c '[splits("[,;]")] | map(select(length > 0))')
echo "$PKGS_ARRAY"

RENV_PKGS_INPUT=""
PKGS_ARRAY=$(echo -n "$RENV_PKGS_INPUT" | jq -R -s -c '[splits("[,;]")] | map(select(length > 0))')
echo "$PKGS_ARRAY"
