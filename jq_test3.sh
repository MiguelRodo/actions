RENV_PKGS_INPUT="pkg1\"; touch pwned; echo \""
PKGS_ARRAY=$(echo "[\"$(echo "$RENV_PKGS_INPUT" | sed 's/[,;]/\" , \"/g')\"]" | sed 's/\"\"//g')
echo "$PKGS_ARRAY"
