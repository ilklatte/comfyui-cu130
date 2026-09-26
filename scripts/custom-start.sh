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
# the password in logs. A contended bbolt lock must never prevent the rest
# of the Pod (ComfyUI, SSH and Jupyter) from starting.
if [ -f "$FILEBROWSER_DB" ] && [ -n "${FILEBROWSER_PASSWORD:-}" ]; then
    echo "Updating the existing FileBrowser admin password from FILEBROWSER_PASSWORD."
    filebrowser_password_updated=false
    for attempt in 1 2 3; do
        if filebrowser_output="$(
            filebrowser --database "$FILEBROWSER_DB" users update admin \
                --password "$FILEBROWSER_PASSWORD" --perm.admin 2>&1
        )"; then
            filebrowser_password_updated=true
            echo "FileBrowser admin password updated."
            break
        fi

        if grep -q 'timeout' <<<"$filebrowser_output" && [ "$attempt" -lt 3 ]; then
            echo "FileBrowser database is locked; retrying password update ($attempt/3)."
            sleep 1
            continue
        fi

        echo "Warning: unable to update the FileBrowser admin password; continuing Pod startup." >&2
        printf '%s\n' "$filebrowser_output" >&2
        break
    done

    if [ "$filebrowser_password_updated" = false ]; then
        echo "Warning: FileBrowser will keep the password stored in its existing database." >&2
    fi
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
