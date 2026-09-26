# syntax=docker/dockerfile:1
ARG PYTHON_IMAGE=python:3.13.7-slim-bookworm
FROM ${PYTHON_IMAGE} AS python313

ARG BASE_IMAGE=runpod/comfyui:1.3.2-comfyuiv0.30.0-cuda13.0
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG COMFYUI_VERSION=v0.37.4
LABEL org.opencontainers.image.base.name=${BASE_IMAGE}
LABEL org.opencontainers.image.version=${COMFYUI_VERSION}

# Keep the RunPod service layer (SSH, Jupyter, FileBrowser and CUDA runtime),
# but run ComfyUI itself with Python 3.13.  The copied /usr/local tree adds
# python3.13 alongside the parent's python3.12 files, so the parent's Jupyter
# entry points that explicitly use python3.12 continue to work.
COPY --from=python313 /usr/local /usr/local

ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    TERM=xterm-256color \
    SHELL=/usr/bin/zsh \
    PIP_CONSTRAINT=/opt/comfyui-runtime-constraints.txt

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        autojump command-not-found git locales language-pack-zh-hans \
        neovim p7zip-full rsync tmux unzip zip zsh \
    && locale-gen zh_CN.UTF-8 \
    && update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN:zh \
    && chsh -s /usr/bin/zsh root \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ARG OH_MY_ZSH_REF=74965c96098134b192f00084f966b4b02438a739
ARG ZSH_AUTOSUGGESTIONS_REF=85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
ARG ZSH_SYNTAX_HIGHLIGHTING_REF=0bfcb582e71d3abe604ce67bc0fe5a21f377507e
ARG OH_MY_TMUX_REF=58a3dcc0d718ec0fa1c0d5a2fddd640a1ad7a5b7
ARG TPM_REF=e261deb1b47614eed3400089ce7197dc68acc4eb
ARG TMUX_SENSIBLE_REF=25cb91f42d020f675bb0a2ce3fbd3a5d96119efa
ARG TMUX_RESURRECT_REF=cff343cf9e81983d3da0c8562b01616f12e8d548
ARG TMUX_CONTINUUM_REF=0698e8f4b17d6454c71bf5212895ec055c578da0

RUN set -eu; \
    clone_at() { \
        repo="$1"; dest="$2"; ref="$3"; \
        git init "$dest"; \
        git -C "$dest" remote add origin "$repo"; \
        git -C "$dest" fetch --depth=1 origin "$ref"; \
        git -C "$dest" checkout --detach FETCH_HEAD; \
        test "$(git -C "$dest" rev-parse HEAD)" = "$ref"; \
    }; \
    clone_at https://github.com/ohmyzsh/ohmyzsh.git /root/.oh-my-zsh "$OH_MY_ZSH_REF"; \
    mkdir -p /root/.oh-my-zsh/custom/plugins; \
    clone_at https://github.com/zsh-users/zsh-autosuggestions.git /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_REF"; \
    clone_at https://github.com/zsh-users/zsh-syntax-highlighting.git /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting "$ZSH_SYNTAX_HIGHLIGHTING_REF"; \
    clone_at https://github.com/gpakosz/.tmux.git /root/.tmux "$OH_MY_TMUX_REF"; \
    mkdir -p /root/.tmux/plugins /root/.tmux/resurrect; \
    clone_at https://github.com/tmux-plugins/tpm.git /root/.tmux/plugins/tpm "$TPM_REF"; \
    clone_at https://github.com/tmux-plugins/tmux-sensible.git /root/.tmux/plugins/tmux-sensible "$TMUX_SENSIBLE_REF"; \
    clone_at https://github.com/tmux-plugins/tmux-resurrect.git /root/.tmux/plugins/tmux-resurrect "$TMUX_RESURRECT_REF"; \
    clone_at https://github.com/tmux-plugins/tmux-continuum.git /root/.tmux/plugins/tmux-continuum "$TMUX_CONTINUUM_REF"; \
    ln -sfn /root/.tmux/.tmux.conf /root/.tmux.conf

COPY config/zshrc /root/.zshrc
COPY config/tmux.conf.local /root/.tmux.conf.local
COPY config/bashrc-zsh /root/.bashrc-zsh
COPY pins.json /opt/custom-image-pins.json

RUN printf '\n# Load the RunPod interactive-shell bridge.\nsource /root/.bashrc-zsh\n' >> /root/.bashrc

# Replace only the image-managed ComfyUI core.  The parent image's bundled
# custom nodes stay in place and user data is never part of /opt/comfyui-baked.
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eu; \
    mkdir -p /tmp/comfyui-source; \
    curl -fSL "https://github.com/Comfy-Org/ComfyUI/archive/refs/tags/${COMFYUI_VERSION}.tar.gz" \
        -o /tmp/comfyui.tar.gz; \
    tar -xzf /tmp/comfyui.tar.gz --strip-components=1 -C /tmp/comfyui-source; \
    rsync -a --delete \
        --exclude='custom_nodes/' \
        --exclude='models/' \
        --exclude='input/' \
        --exclude='output/' \
        --exclude='user/' \
        /tmp/comfyui-source/ /opt/comfyui-baked/; \
    python3.13 -m pip install --no-cache-dir --upgrade pip; \
    python3.13 -m pip install --no-cache-dir --no-build-isolation \
        -r /opt/comfyui-baked/requirements.txt; \
    rm -rf /tmp/comfyui-source /tmp/comfyui.tar.gz; \
    printf '%s\n' \
        "COMFYUI_VERSION=${COMFYUI_VERSION}" \
        "PYTHON_VERSION=3.13" \
        "CUDA_VERSION=13.0" \
        > /opt/comfyui-baked/.runpod-bundle-version

RUN --mount=type=cache,target=/root/.cache/pip \
    python3 - <<'PY'
import json
import pathlib
import shutil
import subprocess

pins = json.load(open('/opt/custom-image-pins.json'))
root = pathlib.Path('/opt/comfyui-baked/custom_nodes')
root.mkdir(parents=True, exist_ok=True)
for node in pins['custom_nodes']:
    dest = root / node['directory']
    checkout = pathlib.Path('/tmp/custom-nodes') / node['directory']
    shutil.rmtree(checkout, ignore_errors=True)
    checkout.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['git', 'init', str(checkout)], check=True)
    subprocess.run(['git', '-C', str(checkout), 'remote', 'add', 'origin', node['repository']], check=True)
    subprocess.run(['git', '-C', str(checkout), 'fetch', '--depth=1', 'origin', node['commit']], check=True)
    subprocess.run(['git', '-C', str(checkout), 'checkout', '--detach', 'FETCH_HEAD'], check=True)
    actual = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != node['commit']:
        raise SystemExit(f"commit mismatch for {node['directory']}: {actual}")
    shutil.rmtree(dest, ignore_errors=True)
    shutil.move(str(checkout), str(dest))
PY

RUN --mount=type=cache,target=/root/.cache/pip \
    set -eu; \
    root=/opt/comfyui-baked/custom_nodes; \
    for dir in "$root"/*; do \
        name="$(basename "$dir")"; \
        if [ "$name" = "ComfyUI-Frame-Interpolation" ]; then \
            if [ -f "$dir/requirements-no-cupy.txt" ]; then python3 -m pip install --no-build-isolation -r "$dir/requirements-no-cupy.txt"; fi; \
            continue; \
        fi; \
        if [ -f "$dir/requirements.txt" ]; then python3 -m pip install --no-build-isolation -r "$dir/requirements.txt"; fi; \
        if [ -f "$dir/install.py" ]; then (cd "$dir" && python3 install.py); fi; \
    done; \
    python3 -m pip uninstall -y cupy cupy-wheel cupy-cuda11x cupy-cuda12x 2>/dev/null || true; \
    python3 -m pip install --no-build-isolation cupy-cuda13x; \
    python3 -m pip check; \
    python3 -c "import torch; assert torch.version.cuda and torch.version.cuda.startswith('13.'), torch.version.cuda"; \
    printf 'CUSTOM_IMAGE=coohh88/runpod-comfyui:cu130\n' >> /opt/comfyui-baked/.runpod-bundle-version; \
    rm -rf /tmp/custom-nodes

# The upstream v1.3.2 launcher is tied to Python 3.12 and names both CUDA
# variants .venv-cu128.  Point it at the isolated Python 3.13/CUDA 13 venv and
# treat the old persistent venv as the migration source.
RUN set -eu; \
    sed -i \
        -e 's|VENV_DIR="$COMFYUI_DIR/.venv-cu128"|VENV_DIR="$COMFYUI_DIR/.venv-cu130-py313"|' \
        -e 's|OLD_VENV_DIR="$COMFYUI_DIR/.venv"|OLD_VENV_DIR="$COMFYUI_DIR/.venv-cu128"|' \
        -e 's|^BAKED_NODES=.*|BAKED_NODES=("ComfyUI-Manager" "ComfyUI-KJNodes" "Civicomfy" "ComfyUI-RunpodDirect" "rgthree-comfy" "ComfyUI-Impact-Pack" "ComfyUI-VideoHelperSuite" "ComfyUI-Easy-Use" "comfyui_controlnet_aux" "ComfyUI-Custom-Scripts" "ComfyUI_essentials" "ComfyUI_LayerStyle" "ComfyUI-Frame-Interpolation" "ComfyUI-GGUF" "ComfyUI-segment-anything-2" "was-node-suite-comfyui")|' \
        -e 's/python3\.12 -m venv/python3.13 -m venv/g' \
        -e 's/\.venv-cu128\/bin\/activate/.venv-cu130-py313\/bin\/activate/g' \
        /start.sh; \
    grep -q 'VENV_DIR="$COMFYUI_DIR/.venv-cu130-py313"' /start.sh; \
    grep -q '"was-node-suite-comfyui"' /start.sh; \
    grep -q 'python3.13 -m venv' /start.sh; \
    ! grep -q 'python3.12 -m venv' /start.sh; \
    python3.13 - <<'PY'
import sys
import torch
import torchaudio
import torchvision

assert sys.version_info[:2] == (3, 13), sys.version
assert torch.version.cuda and torch.version.cuda.startswith("13."), torch.version.cuda
print(sys.version)
print(torch.__version__, torchvision.__version__, torchaudio.__version__, torch.version.cuda)
PY

COPY scripts/custom-start.sh /usr/local/bin/custom-start.sh
RUN chmod +x /usr/local/bin/custom-start.sh \
    && zsh -n /root/.zshrc \
    && tmux -f /root/.tmux.conf new-session -d -s config-check \
    && tmux kill-server

ENTRYPOINT ["/usr/local/bin/custom-start.sh"]
