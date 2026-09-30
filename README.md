# stratus ops

Root-run bash scripts that provision and deploy **vLLM** (OpenAI-compatible) LLM inference servers on Debian/Proxmox hosts with NVIDIA or AMD GPUs. No application code, build system, or CI — checking a change means `bash -n <script>` (and validating any YAML you touch).

## Layout (all under `debian/`)

- **`os-nvidia-setup.sh` / `os-amd-setup.sh`** — base host provisioning: 64 GB swap, apt packages, `uv`, then the GPU stack (NVIDIA installs CUDA via a local `.run`, skipped if `nvidia-smi` exists; AMD installs `amdgpu-dkms` + ROCm). Hosts are Proxmox VMs.
- **`vllm/`** — native (non-Docker) vLLM in a venv: install entry points (`install-vllm-stable.sh` / `...-nightly.sh`), systemd units, per-endpoint `configs/` (`thinking`, `turbo`, `coder`, `instant`, `listen`), and `fixes/`.
- **`docker/`** — Docker deployment: GPU container-toolkit setup, `autoheal`, `sh/` helpers, restart units, and one `*-vllm-docker-setup.sh` per model under `thinking/`, `turbo/`, and `listen/`.
- **`nvidia/power-service/`** — enables `nvidia-smi -pm 1` and caps power at 350 W.
- **`development/`**, **`hugging_face/`**, **`pve-root-resize.sh`** — dev tooling, an HF cache wipe, and a destructive Proxmox LVM resize (requires an empty node).

## Deploying

Single instance per host: the container **and** the service are both named `vllm` on port **8000**, and the served model is `stratus.<endpoint>` (matching the `configs/` subdirectory).

- **Native (venv)** — copy a config from `vllm/configs/<endpoint>/` to `/root/vllm-config.yml`, then run `vllm/install-vllm-stable.sh` (or `...-nightly.sh`) **from the `vllm/` directory** (the sub-steps use relative paths).
- **Docker** — from its own directory, run the model's `debian/docker/<endpoint>/<model>-...-vllm-docker-setup.sh`. It stops/removes any existing `vllm` container, pulls the image, and starts the new one.

Both end by arming a daily restart timer. Recovery is deliberately triple-redundant: systemd `Restart=always`, a daily randomized restart, and the `autoheal` container reacting to the `/health` probe.

For conventions, gotchas, and per-script detail see [`AGENTS.md`](AGENTS.md).
