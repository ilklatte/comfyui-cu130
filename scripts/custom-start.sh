#!/usr/bin/env bash
set -euo pipefail

BAKED_COMFYUI_DIR=/opt/comfyui-baked
WORKSPACE_COMFYUI_DIR=/workspace/runpod-slim/ComfyUI
PINS_FILE=/opt/custom-image-pins.json
FILEBROWSER_DB=/workspace/runpod-slim/filebrowser.db

case ":${LS_COLORS:-}:" in
    *:ow=01\;34:tw=01\;34:*) ;;
    *) export LS_COLORS="${LS_COLORS:+${LS_COLORS}:}ow=01;34:tw=01;34" ;;
esac

# The upstream image uses FILEBROWSER_PASSWORD only when it creates the
# database. Keep an existing network-volume database in sync without exposing
# the password in logs. If the variable is absent, preserve the current login.
if [ -f "$FILEBROWSER_DB" ] && [ -n "${FILEBROWSER_PASSWORD:-}" ]; then
    echo "Updating the existing FileBrowser admin password from FILEBROWSER_PASSWORD."
    filebrowser --database "$FILEBROWSER_DB" users update admin \
        --password "$FILEBROWSER_PASSWORD" --perm.admin
fi

# The upstream entrypoint handles a new volume. For an existing installation,
# refresh only the node directories explicitly owned by this derived image.
if [ -d "$WORKSPACE_COMFYUI_DIR" ]; then
    mkdir -p "$WORKSPACE_COMFYUI_DIR/custom_nodes"
    while IFS= read -r node; do
        source_dir="$BAKED_COMFYUI_DIR/custom_nodes/$node"
        target_dir="$WORKSPACE_COMFYUI_DIR/custom_nodes/$node"
        if [ -d "$source_dir" ]; then
            mkdir -p "$target_dir"
            rsync -a --delete "$source_dir/" "$target_dir/"
        fi
    done < <(python3 - "$PINS_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    for item in json.load(handle)['custom_nodes']:
        print(item['directory'])
PY
    )
fi

exec /start.sh "$@"
