#!/bin/bash
# Exercise the seafile-migrate UPGRADE paths after a fresh install has already booted: fake the
# recorded version stamp to an older version and reboot the stack, so the migrate one-shot takes
# its minor- and major-upgrade branches (schema handling, django migrate) instead of the
# init branch. Self-contained — reuses the installed artifacts, no second package version needed.
# Re-runs boot-check.sh after each simulated upgrade as the health gate. Exits non-zero on failure.
#
# Runs IN PLACE as root, requires systemd — ephemeral testbed only, never a user's live install.
#
# Usage:  upgrade-check.sh [--out FILE]
set -u
OUT="${OUT:-/dev/stdout}"
HERE=$(cd "$(dirname "$0")" && pwd)
STAMP=/var/lib/seafile/current_version
info()  { printf '\n========== %s ==========\n' "$1"; }
error() { local code="$1"; shift; echo "$*" >&2; exit "$code"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) error 2 "unknown option: $1" ;;
  esac
done
[ -d /run/systemd/system ] || error 4 "systemd is not running"
[ -f "$STAMP" ] || error 4 "no version stamp at $STAMP (run the fresh-install boot first)"

installed=$(cat /usr/lib/seafile/version)
major=${installed%%.*}
rc=0; rows=()

simulate() {
  local label="$1" fake="$2"
  info "Upgrade path: $label ($fake -> $installed)"
  systemctl stop seahub.service seafile.service 2>/dev/null
  echo "$fake" > "$STAMP"
  systemctl start seahub.service 2>&1 || true
  sleep 5
  local ok=1
  WAIT=90 bash "$HERE/boot-check.sh" >/dev/null 2>&1 || ok=0
  [ "$(cat "$STAMP")" = "$installed" ] || ok=0
  [ "$(systemctl show -p Result --value seafile-migrate.service)" = success ] || ok=0
  if [ "$ok" = 1 ]; then
    echo "OK $label: migrate succeeded, stamp -> $installed, stack healthy"; rows+=("| $label upgrade ($fake -> $installed) | ✅ |")
  else
    echo "FAIL $label"; rc=1; rows+=("| $label upgrade ($fake -> $installed) | ❌ |")
    systemctl status seafile-migrate.service --no-pager -l 2>&1 | head -15 || true
    journalctl -u seafile-migrate.service --no-pager -n 40 2>&1 || true
  fi
}

# minor: same major.minor, patch 0 (13.0.25 -> stamp 13.0.0)
simulate "minor" "${installed%.*}.0"
# major: previous major (13.0.25 -> stamp 12.0.0), exercises the schema-delta path
[ "$major" -gt 1 ] && simulate "major" "$((major - 1)).0.0"

info "Summary"
[ "$rc" -eq 0 ] && verdict="✅ upgrade paths healthy" || verdict="❌ upgrade path failure (see above)"
[ "$OUT" = /dev/stdout ] || mkdir -p "$(dirname "$OUT")"
{
  echo ""
  echo "| Upgrade simulation | Result |"
  echo "|---|---|"
  printf '%s\n' "${rows[@]}"
  echo ""
  echo "$verdict"
} | if [ "$OUT" = /dev/stdout ]; then cat; else cat >> "$OUT"; fi

[ "$rc" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$rc"
