#!/usr/bin/env bash
# One-time box verification for the tuner. Idempotent; checks, then tells
# you what to fix rather than mutating the box behind your back. The only
# thing it installs is a narrow sudoers rule for the drop-caches helper.
#
#   bash ~/spark-tuner/setup.sh
set -euo pipefail

FAIL=0
ok()  { echo "  ok: $1"; }
bad() { echo "  MISSING: $1" >&2; FAIL=1; }

check() {  # check <label> <command...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi
}

echo "==> docker + GPU"
check "docker" command -v docker
if [ -e /var/run/cdi/nvidia.yaml ] || [ -e /etc/cdi/nvidia.yaml ]; then
  ok "CDI spec (GPU access path on this box — no nvidia docker runtime)"
else
  bad "CDI spec at /var/run/cdi/nvidia.yaml or /etc/cdi/nvidia.yaml"
fi
check "nvidia-smi" command -v nvidia-smi

echo "==> HF weight cache"
if [ -d "$HOME/.cache/huggingface" ]; then
  ok "$HOME/.cache/huggingface ($(du -sh "$HOME/.cache/huggingface" 2>/dev/null | cut -f1))"
else
  bad "$HOME/.cache/huggingface"
fi

echo "==> pinned vllm-gb10 image"
IMAGE="ghcr.io/timothystewart6/vllm-gb10@sha256:fa87aea586e02719aba804f76e0895d1f096e8c387573e7981e2681589b3b712"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  ok "image present"
else
  echo "  pulling $IMAGE"
  if docker pull "$IMAGE"; then ok "image pulled"; else bad "image pull"; fi
fi

echo "==> passwordless drop-caches helper"
HELPER=/usr/local/bin/spark-tuner-dropcaches
if sudo -n "$HELPER" >/dev/null 2>&1; then
  ok "$HELPER runs without a password"
else
  echo "  installing helper + sudoers rule (sudo will prompt once)"
  sudo tee "$HELPER" >/dev/null <<'EOF'
#!/bin/sh
sync
echo 3 > /proc/sys/vm/drop_caches
EOF
  sudo chmod 755 "$HELPER"
  echo "$USER ALL=(root) NOPASSWD: $HELPER" | sudo tee /etc/sudoers.d/spark-tuner-dropcaches >/dev/null
  sudo chmod 440 /etc/sudoers.d/spark-tuner-dropcaches
  if sudo -n "$HELPER" >/dev/null 2>&1; then
    ok "helper installed"
  else
    bad "helper still needs a password"
  fi
fi

echo "==> benchmark harness (sparkrun + llama-benchy)"
if command -v sparkrun >/dev/null; then
  ok "sparkrun"
else
  echo "  not installed yet — install decided in the runner milestone"
fi
if command -v llama-benchy >/dev/null; then
  ok "llama-benchy"
else
  echo "  not installed yet — install decided in the runner milestone"
fi

echo
if [ "$FAIL" = 0 ]; then
  echo "setup: box ready"
else
  echo "setup: fix the MISSING items above"
  exit 1
fi
