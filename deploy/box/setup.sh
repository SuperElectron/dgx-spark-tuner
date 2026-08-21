#!/usr/bin/env bash
# One-time box verification for the tuner. Idempotent; checks, then tells
# you what to fix rather than mutating the box behind your back. The only
# thing it installs is a narrow sudoers rule for drop-caches.
#
#   bash ~/spark-tuner/setup.sh
set -euo pipefail

FAIL=0
ok()   { echo "  ok: $1"; }
bad()  { echo "  MISSING: $1" >&2; FAIL=1; }

echo "==> docker + GPU"
command -v docker >/dev/null && ok "docker" || bad "docker"
if [ -e /var/run/cdi/nvidia.yaml ] || [ -e /etc/cdi/nvidia.yaml ]; then
  ok "CDI spec (GPU access path on this box — no nvidia docker runtime)"
else
  bad "CDI spec at /var/run/cdi/nvidia.yaml or /etc/cdi/nvidia.yaml"
fi
command -v nvidia-smi >/dev/null && ok "nvidia-smi" || bad "nvidia-smi"

echo "==> HF weight cache"
[ -d "$HOME/.cache/huggingface" ] \
  && ok "$HOME/.cache/huggingface ($(du -sh "$HOME/.cache/huggingface" 2>/dev/null | cut -f1))" \
  || bad "$HOME/.cache/huggingface"

echo "==> pinned vllm-gb10 image"
IMAGE="ghcr.io/timothystewart6/vllm-gb10@sha256:fa87aea586e02719aba804f76e0895d1f096e8c387573e7981e2681589b3b712"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  ok "image present"
else
  echo "  pulling $IMAGE"
  docker pull "$IMAGE" && ok "image pulled" || bad "image pull"
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
  sudo -n "$HELPER" >/dev/null 2>&1 && ok "helper installed" || bad "helper still needs a password"
fi

echo "==> benchmark harness (sparkrun + llama-benchy)"
command -v sparkrun >/dev/null && ok "sparkrun" \
  || echo "  not installed yet — install decided in the runner milestone"
command -v llama-benchy >/dev/null && ok "llama-benchy" \
  || echo "  not installed yet — install decided in the runner milestone"

echo
[ "$FAIL" = 0 ] && echo "setup: box ready" || { echo "setup: fix the MISSING items above"; exit 1; }
