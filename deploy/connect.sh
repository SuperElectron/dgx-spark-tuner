#!/usr/bin/env bash
# The laptop's one entry point to the DGX Spark box.
#
#   ./deploy/connect.sh sync              # rsync deploy/box/ -> box:~/spark-tuner/
#   ./deploy/connect.sh ssh <cmd...>      # run anything on the box
#   ./deploy/connect.sh setup             # one-time box verification (may prompt sudo)
#   ./deploy/connect.sh start [env...]    # start benchmark engine, e.g. start MODEL=... PORT=8100
#   ./deploy/connect.sh stop              # stop it
#   ./deploy/connect.sh status            # JSON env fingerprint
#
# Connection config: .claude/box.json (gitignored). Overrides:
#   BOX_TARGET=user@host  SSH_KEY=~/.ssh/other  BOX_DOMAIN=other.ts.net
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="${SSH_KEY:-$HOME/.ssh/runkali_spark}"
DOMAIN="${BOX_DOMAIN:-tailae2b1.ts.net}"

if [ -z "${BOX_TARGET:-}" ]; then
  CONF="$HERE/../.claude/box.json"
  [ -f "$CONF" ] || { echo "no BOX_TARGET and no $CONF" >&2; exit 1; }
  BOX_TARGET="$(python3 - "$CONF" "$DOMAIN" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
host = c["host"]
if "." not in host:
    host += "." + sys.argv[2]
print(c["username"] + "@" + host)
PY
)"
fi

SSH=(ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=10 "$BOX_TARGET")

CMD="${1:-}"; shift || true
case "$CMD" in
  sync)
    echo "==> $HERE/box/  ->  $BOX_TARGET:spark-tuner/"
    rsync -az --delete --exclude '__pycache__/' \
      -e "ssh -i $KEY -o BatchMode=yes" "$HERE/box/" "$BOX_TARGET:spark-tuner/"
    ;;
  ssh)     exec "${SSH[@]}" "$@" ;;
  setup)   exec ssh -t -i "$KEY" "$BOX_TARGET" bash spark-tuner/setup.sh ;;
  start)   exec "${SSH[@]}" "$*" bash spark-tuner/start.sh ;;
  stop)    exec "${SSH[@]}" bash spark-tuner/stop.sh "$@" ;;
  status)  exec "${SSH[@]}" bash spark-tuner/status.sh "$@" ;;
  *) grep '^#   ' "$0" | sed 's/^#   //'; exit 1 ;;
esac
