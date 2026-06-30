RENV_PKGS_INPUT='pkg1,pkg2" , "pkg3'
PKGS_ARRAY=$(echo "$RENV_PKGS_INPUT" | jq -R -c '[splits("[,;]")] | map(select(length > 0))')
echo "$PKGS_ARRAY"

RENV_PKGS_INPUT=''
PKGS_ARRAY=$(echo "$RENV_PKGS_INPUT" | jq -R -c '[splits("[,;]")] | map(select(length > 0))')
echo "$PKGS_ARRAY"
