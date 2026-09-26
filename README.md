# RunPod ComfyUI CUDA 13.0

Custom RunPod image that keeps the service layer from
`runpod/comfyui:1.3.2-comfyuiv0.30.0-cuda13.0`, while replacing the ComfyUI
runtime with ComfyUI `v0.37.4` on Python `3.13`. The published repository is
`coohh88/runpod-comfyui` under CUDA-specific tags.

## Included environment

- Chinese UTF-8 locale (`zh_CN.UTF-8`)
- ComfyUI `v0.37.4`, Python `3.13` and the parent's CUDA 13.0 PyTorch stack
- Zsh as root's login shell, Oh My Zsh, autosuggestions and syntax highlighting
- Automatic Zsh login for interactive Bash terminals opened by RunPod or Jupyter
- Automatic activation of the persistent ComfyUI venv in interactive terminals
- tmux, Oh My Tmux, TPM, resurrect, continuum, neovim and autojump
- zip, unzip and p7zip (`7z`)
- 13 pinned general-purpose ComfyUI custom-node packs listed in `pins.json`
- Blue display for world-writable and sticky world-writable directories in both `ls` and Zsh completion

ComfyUI keeps the upstream persistent layout at
`/workspace/runpod-slim/ComfyUI`. Tmux resurrect data is intentionally local to
the container at `/root/.tmux/resurrect` and is not persisted in `/workspace`.
When `FILEBROWSER_PASSWORD` is set, every pod start also synchronizes that
value to the existing `/workspace/runpod-slim/filebrowser.db` admin account.
The ComfyUI environment is `/workspace/runpod-slim/ComfyUI/.venv-cu130-py313`.
On the first boot after upgrading this image, the old `.venv-cu128` environment
is timestamped and moved aside before user-node dependencies are reinstalled.

## CircleCI setup

Connect `ilklatte/comfyui-cu130` to CircleCI and add these project environment
variables:

| Variable | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | Docker Hub account name |
| `DOCKERHUB_TOKEN` | Docker Hub token with Read & Write permission |

Commits on `main` only run validation. Publishing happens only when a tag that
matches `vN` is pushed. For example, pushing `v2` publishes both `cu130-v2`
and `cu130-latest`. The Docker repository is read from `pins.json`; no
`DOCKER_IMAGE` CircleCI variable is needed. No RunPod template is updated.

## Local validation

```bash
bash -n scripts/custom-start.sh
python3 -m json.tool pins.json >/dev/null
python3 scripts/validate.py
```
