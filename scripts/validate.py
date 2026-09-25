#!/usr/bin/env python3
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED_BASE = "runpod/comfyui:1.3.2-comfyuiv0.30.0-cuda13.0"
EXPECTED_IMAGE = "coohh88/runpod-comfyui"

pins = json.loads((ROOT / "pins.json").read_text())
dockerfile = (ROOT / "Dockerfile").read_text()
tmux = (ROOT / "config/tmux.conf.local").read_text()
circleci = (ROOT / ".circleci/config.yml").read_text()

assert pins["base_image"] == EXPECTED_BASE
assert pins["docker_image"] == EXPECTED_IMAGE
assert len(pins["custom_nodes"]) == 13
assert len({item["directory"] for item in pins["custom_nodes"]}) == 13
assert all(re.fullmatch(r"[0-9a-f]{40}", item["commit"]) for item in pins["custom_nodes"])
assert f"ARG BASE_IMAGE={EXPECTED_BASE}" in dockerfile
assert "pip install --no-build-isolation cupy-cuda13x;" in dockerfile
assert "pip install --no-build-isolation cupy-cuda12x;" not in dockerfile
assert "PIP_CONSTRAINT=/opt/comfyui-runtime-constraints.txt" in dockerfile
assert "LC_ALL=zh_CN.UTF-8" in dockerfile
assert "ENTRYPOINT [\"/usr/local/bin/custom-start.sh\"]" in dockerfile
assert "set -g prefix C-b" in tmux and "set -g mouse on" in tmux
assert "@resurrect-dir '/root/.tmux/resurrect'" in tmux
assert "@continuum-restore 'off'" in tmux
assert "/workspace/.tmux" not in tmux
assert 'ow=01;34:tw=01;34' in (ROOT / "config/zshrc").read_text()
start_script = (ROOT / "scripts/custom-start.sh").read_text()
assert 'ow=01;34:tw=01;34' in start_script
assert 'FILEBROWSER_PASSWORD' in start_script
assert 'users update admin' in start_script
assert '--database "$FILEBROWSER_DB"' in start_script
bash_bridge = (ROOT / "config/bashrc-zsh").read_text()
assert 'case $-' in bash_bridge and 'exec /usr/bin/zsh -l' in bash_bridge
assert 'source /root/.bashrc-zsh' in dockerfile
assert "pipeline.git.tag matches /^v[1-9][0-9]*$/" in circleci
assert "--platform linux/amd64" in circleci
assert 'IMAGE_TAG="cu130-${CIRCLE_TAG}"' in circleci
assert 'ROLLING_TAG="cu130-latest"' in circleci
print("validation passed")
