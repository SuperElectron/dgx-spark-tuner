#!/usr/bin/env bash
# Read the box at rest. One ssh, no writes, no benchmark.
#
#   sweep.sh [--force]
#
# Refuses (exit 3) when anything holds the GPU: the sweep shares the card with
# whatever is running, and a reading taken under load is not a reading at rest.
# --force is for a box you have already established is idle-but-lying; it still
# changes nothing.
#
# Exit 2 = no .claude/box.json, or it is missing host/username.
set -uo pipefail

force=0
[ "${1:-}" = "--force" ] && force=1

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
box="$repo/.claude/box.json"
[ -f "$box" ] || { echo "sweep: no $box" >&2; exit 2; }

host="$(jq -r '.host // empty' "$box")"
user="$(jq -r '.username // empty' "$box")"
[ -n "$host" ] && [ -n "$user" ] || { echo "sweep: box.json needs host and username" >&2; exit 2; }
alias="${host%%.*}"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 "$user@$host")

apps="$("${SSH[@]}" 'nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader' 2>&1)"
rc=$?
[ $rc -eq 0 ] || { echo "sweep: cannot reach $host ($apps)" >&2; exit 2; }
if [ -n "$apps" ] && [ $force -eq 0 ]; then
  echo "sweep: the card is busy — refusing" >&2
  echo "$apps" >&2
  exit 3
fi

echo "box       $alias  ($host)"
echo "swept     $(date +%F) $(date +%H:%M) local"
[ -n "$apps" ] && echo "forced    compute apps present: $apps"

"${SSH[@]}" '
  q() { nvidia-smi --query-gpu="$1" --format=csv,noheader; }
  echo "gpu       $(q name)"
  echo "driver    $(q driver_version)   cuda $(nvidia-smi -q | awk -F": " "/CUDA Version/{print \$2; exit}")"
  echo "kernel    $(uname -r)   $(lsb_release -ds 2>/dev/null)"
  echo "clocks    now $(q clocks.current.graphics) / max $(q clocks.max.graphics)   mem now $(q clocks.current.memory) / max $(q clocks.max.memory)"
  echo "power     draw $(q power.draw)   limit $(q power.limit)   enforced $(q enforced.power.limit)"
  echo "thermal   gpu $(q temperature.gpu) C"
  echo "policy    persistence $(q persistence_mode)   perf state $(q pstate)   cpu governor $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
  active=$(nvidia-smi -q -d PERFORMANCE | grep ": Active" | sed "s/ \{2,\}/ /g;s/^ //" | paste -sd"; " -)
  echo "throttle  $(q clocks_throttle_reasons.active)   ${active:-nothing active}"
  echo "memory    $(free -g | awk "/^Mem:/{print \$2\" GiB total, \"\$7\" GiB available\"}")"
  echo "disk      $(df -h --output=avail,pcent / | tail -1 | tr -s " " | sed "s/^ //") used on /"
  echo "uptime    $(uptime -p)"
  echo "images"
  docker images --digests --format "          {{.Repository}}:{{.Tag}} {{.Digest}}" 2>/dev/null \
    | grep -v "<none>$" | grep -i "vllm\|spark" | head -10
  echo "running"
  docker ps --format "          {{.Image}}  {{.Names}}  {{.Status}}" 2>/dev/null | head -20
'
