# RunPod ComfyUI CUDA 13.0

Custom RunPod image based on
`runpod/comfyui:1.3.2-comfyuiv0.30.0-cuda13.0`. The published repository is
`coohh88/runpod-comfyui-cu130`.

## Included environment

- Chinese UTF-8 locale (`zh_CN.UTF-8`)
- Zsh as root's login shell, Oh My Zsh, autosuggestions and syntax highlighting
- tmux, Oh My Tmux, TPM, resurrect, continuum, neovim and autojump
- 13 pinned general-purpose ComfyUI custom-node packs listed in `pins.json`

ComfyUI keeps the upstream persistent layout at
`/workspace/runpod-slim/ComfyUI`. Tmux resurrect data is intentionally local to
the container at `/root/.tmux/resurrect` and is not persisted in `/workspace`.

## CircleCI setup

Connect `ilklatte/comfyui-cu130` to CircleCI and add these project environment
variables:

| Variable | Value |
| --- | --- |
| `DOCKER_IMAGE` | `coohh88/runpod-comfyui-cu130` |
| `TEMPLATE_REPOSITORY_URL` | `https://github.com/ilklatte/comfyui-cu130.git` |
| `DOCKERHUB_USERNAME` | Docker Hub account name |
| `DOCKERHUB_TOKEN` | Docker Hub token with Read & Write permission |

Commits on `main` only run validation. Publishing happens only when a tag that
matches `vN` is pushed. For example, pushing `v1` publishes both `v1` and
`latest`. No RunPod template is updated by this pipeline.

## Local validation

```bash
bash -n scripts/custom-start.sh
python3 -m json.tool pins.json >/dev/null
python3 scripts/validate.py
```
