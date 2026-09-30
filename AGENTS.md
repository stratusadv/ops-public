# AGENTS.md

This is an ops repository: a collection of root-run bash provisioning and deployment scripts for running vLLM (OpenAI-compatible) LLM inference servers on Debian/Proxmox hosts with NVIDIA or AMD GPUs. There is no application code, no build system, no test suite, and no CI. "Testing" a change means syntax-checking the shell (`bash -n script.sh`) and, where relevant, validating YAML configs.

## Directory layout

Everything lives under `debian/`:

- `os-nvidia-setup.sh` / `os-amd-setup.sh` — base host provisioning: 64 GB swapfile, apt packages, `uv` (Astral), then GPU stack. NVIDIA path installs CUDA 13.3.1 (driver 610.43.02) via local `.run` installer, skipped if `nvidia-smi` exists. AMD path installs `amdgpu-dkms` + full ROCm 7.2.4 (noble) and `modprobe amdgpu`. Both install `proxmox-headers-$(uname -r)` — hosts are Proxmox VMs.
- `vllm/` — native (non-Docker) vLLM deployment
  - `install-vllm-stable.sh` / `install-vllm-nightly.sh` — entry points; they `source ./sh/environment-setup.sh`, `./sh/vllm-{stable,nightly}-install.sh`, `./sh/vllm-service-install.sh` in that order.
  - `sh/` — the actual steps (see below).
  - `vllm.sh` — what systemd runs: activates `/root/vllm-venv`, runs `vllm serve --config /root/vllm-config.yml --trust-remote-code --enable-prefix-caching --enable-chunked-prefill`. Commented-out env vars (NCCL debug, `VLLM_LOGGING_LEVEL=DEBUG`, P2P toggles) are the debugging knobs.
  - `vllm.service` / `vllm-restart.service` / `vllm-restart.timer` — systemd units.
  - `configs/` — vLLM serve configs as YAML, grouped by served endpoint: `thinking/`, `turbo/`, `coder/`, `instant/`, `listen/`.
  - `fixes/` — monkey-patches applied by copying files into the installed venv or to `/root/` (see Gotchas).
  - `usage.md` — **out of date**: it references `install-vllm.sh`, which no longer exists (split into stable/nightly).
- `docker/` — Docker-based deployment
  - `nvidia-container-toolkit-setup.sh` / `amd-container-toolkit-setup.sh` — Docker CE + GPU container toolkit, `nvidia-ctk`/`amd-ctk runtime configure`, restart docker.
  - `autoheal-docker-setup.sh` — runs `willfarrell/autoheal`; it watches and restarts any container labeled `autoheal=true` (all vLLM setup scripts apply that label).
  - `sh/vllm-docker-stop-and-remove.sh` — `docker stop vllm && docker container rm vllm`.
  - `sh/vllm-docker-restart-service-install.sh` — installs the daily restart timer (see below).
  - `vllm-docker-restart.service` / `vllm-docker-restart.timer` — oneshot `docker restart vllm`, daily.
  - `thinking/`, `turbo/`, `listen/` — one `*-vllm-docker-setup.sh` per model deployment.
  - `listen/Dockerfile` + `config.yml` — the only locally built image (`stratus/listen`): `vllm/vllm-openai` base plus `vllm[audio]` for Qwen3-ASR.
- `nvidia/power-service/` — installs `nvidia-power.service` (oneshot, after `nvidia-persistenced`, `RemainAfterExit=yes`) which runs `nvidia-smi -pm 1` and caps power at 350 W (`nvidia-smi -pl 350`).
- `hugging_face/remove-all-hub-data.sh` — wipes `~/.cache/huggingface/hub`.
- `pve-root-resize.sh` — **destructive** Proxmox node LVM surgery: removes `/dev/pve/data` LV, resizes root to 500 G, `resize2fs`, recreates `data` thinpool. Requires an empty node (it prompts for confirmation).
- `development/setup-remote-development.sh` — dev-tooling install: git/gh/lazygit/helix (builds hx grammars), `uv tool install ruff ty python-lsp-server`.

## How a deployment works

Two parallel paths, both single-instance per host (container and service are always named `vllm`; port 8000):

**Native (vLLM in a venv):**
1. Copy a config from `vllm/configs/<endpoint>/` to `/root/vllm-config.yml` (the venv install refuses to run without it).
2. Run `install-vllm-stable.sh` (or nightly) **from the `vllm/` directory** — the sub-steps use relative `./sh/` paths and assume the config units (`vllm.sh`, `*.service`) are in the CWD.
3. `environment-setup.sh` interactively prompts for a Hugging Face token, then writes `HF_TOKEN=...` and `UV_TORCH_BACKEND=cu130` into `/etc/environment` and exits if no token is set. The service reads it via `EnvironmentFile=-/etc/environment`.
4. Install steps create `/root/vllm-venv` with `uv` (stable pins `--python 3.12`; nightly installs `vllm --pre` from `wheels.vllm.ai/nightly/cu130` + pytorch cu130 wheel indexes with `--index-strategy unsafe-best-match`, plus flashinfer for cu130). Both also install `qwen-asr[vllm]` and `vllm[audio]` — ASR support is expected even on text deployments.
5. Service install copies `vllm.sh` → `/usr/local/bin/`, units → `/etc/systemd/system/`, then starts with `rm -rf /dev/shm/*` in between (intentional: clears stale shared memory for vLLM's multiproc workers).

**Docker:**
1. Run the model-specific `*-vllm-docker-setup.sh`. It sources stop-and-remove, pulls the image (`vllm/vllm-openai:latest` for NVIDIA, `vllm/vllm-openai-rocm:latest` for AMD), then `docker run -d` with model name + flags inline (no compose). The `listen/` script instead builds the local image and passes `HF_TOKEN`/`VLLM_API_KEY` env vars, mounting its `config.yml` read-only.
2. Ends by sourcing the restart-timer install.

**Recovery/ops model (intentional, don't "fix"):** three redundant restart mechanisms run on purpose to shed memory and recover from hangs — systemd `Restart=always` (15 s), a daily randomized restart timer (native: 10:00 + up to 2 h `RandomizedDelaySec=7200`; docker: `docker restart vllm`), and the autoheal container reacting to the `--health-cmd='curl -f http://localhost:8000/health'` probe (600 s start period).

## Conventions

- Scripts are bash, run as root on the target host (root/EUID checks in some, not all). Only the Docker toolkit setup scripts and the listen setup script use `set -e`/`set -euo pipefail`; the rest tolerate individual command failures — new scripts should match the surrounding style, not silently add strict mode that changes behavior.
- CWD matters: sub-steps are sourced with relative paths (`./sh/...`, `../sh/...`), so entry scripts must be executed from their own directory.
- Endpoint naming: `served-model-name` is always `stratus.<endpoint>` and matches the `configs/` subdirectory name (`stratus.thinking`, `stratus.turbo`, `stratus.coder`, `stratus.instant`, `stratus.listen`). Config filenames are roughly `<model>-<quantization>-config.yml`.
- User-facing `echo` output uses emoji status markers (✅ ❌ ℹ️) — house style.
- NVIDIA vs AMD differences are structural, not cosmetic: AMD container runs need `--device=/dev/kfd --device=/dev/dri --group-add=video --group-add=render`, `--network=host` (no `-p` port mapping), and a block of RCCL/NCCL env vars (`NCCL_P2P_DISABLE=1`, `NCCL_SOCKET_IFNAME=lo`, etc.) plus `--enforce-eager`. NVIDIA runs just use `--gpus all -p 8000:8000`.
- `vllm/configs/thinking/` and `coder/` configs carry hardware notes in comments (e.g. "2 x NVIDIA RTX 6000 Pro Blackwell", "Blackwell High VRAM") — keep such notes when editing configs.
- GPU memory utilization runs high (0.85–0.96) and `max-model-len` is usually 262144 for thinking/turbo; speculative decoding (`speculative-config` with `mtp`/`dspark`/`dflash`) is a common tuning knob. The `dflash` method takes a DFlash2 draft *head* repo in `model` (e.g. `incoai/Qwen3.8-27B-DFlash2` or `ProCreations/Ternary-Bonsai-2-27B-DFlash2` — same `DFlash2DraftModel` architecture, loaded from the repo's BF16 `model.safetensors`, not the GGUF); `num_speculative_tokens` should match the draft's tested default (7 for incoai, 3 for the ProCreations r2-dflash head).
- `kv-cache-dtype: fp8` (and FP8 compute in general) only runs on Ada/Blackwell (SM 8.9+). On Ampere RTX 3090 (SM 8.6) prefer AWQ INT4 targets and omit `--kv-cache-dtype fp8` — `turbo/qwen-3-8-27b-nvidia-vllm-docker-setup.sh` is the 3090 reference: Qwen3.8-27B AWQ INT4 + `incoai/Qwen3.8-27B-DFlash2` (instruct mode, TP2, 64K context).

## Gotchas

- `debian/vllm/fixes/minimax/apply-minimax-fix.sh` copies the parser into `~/vllm-venv/lib/python3.13/site-packages/...`, but the **stable** install creates the venv with `--python 3.12`. The fix only matches a python3.13 (nightly/default) venv; verify the actual venv python before applying.
- `fixes/gemma/tool_chat_template_gemma4.jinja` is referenced by configs as `chat-template: /root/tool_chat_template_gemma4.jinja` — it must be copied to `/root/` by hand first ("Need to download Gemma 4 Template" comments mark which configs require it).
- `docker/sh/vllm-docker-restart-service-install.sh` does `cp vllm-docker-restart.service ...` with a path relative to CWD, but the unit files live in `docker/`, one level above the script and in `docker/thinking/` etc. Where it works from depends on the CWD at runtime — expect `cp` failures and a broken timer if run from a model subdirectory.
- `vllm/usage.md` is stale (`install-vllm.sh` does not exist).
- `vllm/configs/listen/qwen3-asr-2b-config.yml` names a "2b" model but points at `Qwen/Qwen3-ASR-1.7B`; `docker/listen/config.yml` does the same.
- The HF token is stored in plaintext in `/etc/environment` — treat that file as secret material; never log or echo its contents.
- The `docker run` containers are all named `vllm`; deploying a second model on the same host requires running the new setup script first (it stops/removes the old container) — they are mutually exclusive by design.
- `environment-setup.sh` is interactive (`read -sp` for the token); it hangs if run non- interactively without a pre-set `HF_TOKEN` in `/etc/environment` (it re-reads the file before exiting).
- `os-nvidia-setup.sh` downloads a ~large CUDA `.run` into the CWD and reuses it if present; same pattern in the AMD script.
- The deepseek "optimized" docker setup (`docker/thinking/deep-seek-v4-flash-0731-optimized-vllm-docker-setup.sh`) contains a **malformed** `--reasoning-config` JSON value (unbalanced quotes) — do not copy that line as a template.

## Verifying changes

On a live host, the relevant checks are:

```bash
systemctl status vllm                      # native deployment
curl -f http://localhost:8000/health       # either deployment
curl -s http://localhost:8000/v1/models    # served-model-name check
journalctl -u vllm -f                      # native logs
docker logs vllm                           # docker logs
systemctl list-timers vllm-restart.timer   # daily restart armed
nvidia-smi / rocminfo                      # GPU stack
```
