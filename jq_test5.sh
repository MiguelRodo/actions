RENV_PKGS_INPUT="pkg1;pkg2"
echo "$RENV_PKGS_INPUT" | jq -R -c '[splits("[,;]")] | map(select(length > 0))'

RENV_PKGS_INPUT=""
echo -n "$RENV_PKGS_INPUT" | jq -R -c '[splits("[,;]")] | map(select(length > 0))'

echo "" | jq -R -c '[splits("[,;]")] | map(select(length > 0))'
