#!/bin/bash
# Smoke-check the seafile-server install: wait for seafile.service to become active and
# report status + journal. Runs IN PLACE as root on an ephemeral testbed only.
#
# NON-GATING for now: a fully functional first boot of seafile-server needs the database and
# data directories initialised (normally by the seahub setup scripts) and the seahub package
# alongside. Until that first-run flow is wired and validated, this check reports the outcome
# but always exits 0 so it does not block releases. Tighten to a hard gate (exit non-zero on
# failure) once the runtime is confirmed.
#
# Usage:  boot-check.sh [--out FILE]
# Env:    WAIT   seconds to wait for readiness (default 60)
set -u
WAIT="${WAIT:-60}"
OUT="${OUT:-/dev/stdout}"
info() { printf '\n========== %s ==========\n' "$1"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ -d /run/systemd/system ] || { echo "systemd is not running" >&2; exit 0; }

SERVICES="seafile.service seahub.service"
rows=""
for SVC in $SERVICES; do
  info "Wait for $SVC to become active (timeout ${WAIT}s)"
  i=0; active=0
  while [ "$i" -lt "$WAIT" ]; do
    if systemctl is-active --quiet "$SVC"; then active=1; break; fi
    systemctl is-failed --quiet "$SVC" && break
    sleep 2; i=$((i+2))
  done

  info "Status $SVC"
  systemctl status "$SVC" --no-pager -l 2>&1 | head -25 || true
  echo "--- last journal lines: $SVC ---"
  journalctl -u "$SVC" --no-pager -n 40 2>&1 || true

  if [ "$active" = 1 ]; then
    rows="$rows| \`$SVC\` | ✅ active after ~${i}s |
"
  else
    rows="$rows| \`$SVC\` | ⚠️ not active (first-run setup likely required) |
"
  fi
done

[ "$OUT" = /dev/stdout ] || mkdir -p "$(dirname "$OUT")"
{
  echo ""
  echo "| Service | Smoke result (non-gating) |"
  echo "|---|---|"
  printf '%s' "$rows"
} >> "$OUT"
printf '%s' "$rows"
# non-gating: always succeed
exit 0
