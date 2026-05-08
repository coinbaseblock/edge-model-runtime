#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — safe interactive uninstaller
# =============================================================================
# Default behavior PRESERVES models. To delete models, use 20-wipe-models.sh
# or pick the explicit "Wipe all" option here.
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

section "🗑️  edge-model-runtime — uninstall"

cat <<EOF
Choose what to remove:

  1) Stop containers only             (safe, models kept)
  2) Stop + remove containers/images  (safe, models kept)   [= scripts/10-cleanup-docker.sh]
  3) WIPE EVERYTHING (incl. models)   (DANGEROUS)            [= scripts/20-wipe-models.sh]
  q) Quit

EOF

read -r -p "Selection: " choice
case "$choice" in
  1) bash "$SCRIPT_DIR/02-stop.sh" ;;
  2) bash "$SCRIPT_DIR/10-cleanup-docker.sh" ;;
  3) bash "$SCRIPT_DIR/20-wipe-models.sh" ;;
  q|Q|"") log "Cancelled." ;;
  *) err "Invalid selection: $choice"; exit 1 ;;
esac
