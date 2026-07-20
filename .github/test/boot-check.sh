#!/bin/bash
# Gate on a functional first boot of the seafile stack: the seafile-migrate one-shot must have
# succeeded, seafile and seahub must be active, each must log its healthy startup line in
# journald, and seahub must answer HTTP 200 on its login page — which exercises the whole chain
# (database init/migrate, seaf-server RPC, cache, static manifest). Waits up to WAIT for readiness,
# prints logs on failure, exits non-zero on failure (the
# release gate). prepare.sh already started the services; this never starts anything. Runs IN PLACE
# as root, requires systemd, reads journald — ephemeral testbed only, never a user's live install.
#
# Usage:  boot-check.sh [--out FILE]    # --out: append the result table to FILE (default: stdout)
# Env:    WAIT   seconds to wait for readiness (default 120)
set -u
WAIT="${WAIT:-120}"
OUT="${OUT:-/dev/stdout}"
URL="http://127.0.0.1:8000/accounts/login/"
info()  { printf '\n========== %s ==========\n' "$1"; }
error() { local code="$1"; shift; echo "$*" >&2; exit "$code"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) error 2 "unknown option: $1" ;;
  esac
done
[ -d /run/systemd/system ] || error 4 "systemd is not running (/run/systemd/system missing)"
rc=0; rows=()

http_code() { curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo 000; }
has_msg() { journalctl -u "$1" --no-pager 2>/dev/null | grep -qF "$2"; }

info "Wait for seahub to answer at $URL (timeout ${WAIT}s)"
i=0; code=000
while [ "$i" -lt "$WAIT" ]; do
  for s in seafile-migrate seafile seahub; do
    systemctl is-failed --quiet "$s.service" && { echo "  $s entered failed state"; break 2; }
  done
  code=$(http_code); [ "$code" = 200 ] && break
  sleep 2; i=$((i+2))
done
echo "  after ~${i}s: HTTP $code"

info "seafile-migrate one-shot result"
mig=$(systemctl show -p Result --value seafile-migrate.service 2>/dev/null)
if [ "$mig" = success ]; then mark="✅"; echo "MIGRATE OK (Result=success)"
else mark="❌"; echo "MIGRATE FAIL (Result=$mig)"; rc=1; fi
rows+=("| \`seafile-migrate\` | one-shot Result=success | $mark |")

info "Service active state"
for s in seafile seahub; do
  if systemctl is-active --quiet "$s.service"; then mark="✅"; echo "SVC OK $s active"
  else mark="❌"; echo "SVC FAIL $s active"; rc=1; fi
  rows+=("| \`$s\` | active | $mark |")
done

info "Startup log messages (each service reporting healthy)"
# Stable "running appropriately" markers per unit; revisit if upstream changes the wording.
check_log() {
  local unit="$1" msg="$2" mark
  if has_msg "$unit" "$msg"; then mark="✅"; echo "LOG OK   $unit: \"$msg\""
  else mark="❌"; echo "LOG MISS $unit: \"$msg\""; rc=1; fi
  rows+=("| \`$unit\` | log: \`$msg\` | $mark |")
}
check_log seafile-migrate.service "seafile-migrate: done"   # our migrate one-shot completed
check_log seafile.service         "Use database"            # seaf-server initialised its DB backend
check_log seahub.service          "Listening at:"           # gunicorn bound and serving

info "HTTP login page"
if [ "$code" = 200 ]; then mark="✅"; echo "HTTP OK 200"
else mark="❌"; echo "HTTP FAIL $code"; rc=1; fi
rows+=("| seahub | GET /accounts/login/ = 200 | $mark |")

if [ "$rc" != 0 ]; then
  for s in seafile-migrate seafile seahub; do
    echo "--- status + last 60 journal lines: $s ---"
    systemctl status "$s.service" --no-pager -l 2>&1 | head -20 || true
    journalctl -u "$s.service" --no-pager -n 60 2>&1 || true
  done
fi

info "Summary"
[ "$rc" -eq 0 ] && verdict="✅ boot: migrate succeeded, seafile + seahub active, login page 200" \
                || verdict="❌ boot: see failures above"
[ "$OUT" = /dev/stdout ] || mkdir -p "$(dirname "$OUT")"
{
  echo ""
  echo "| Component | Assertion | Result |"
  echo "|---|---|---|"
  printf '%s\n' "${rows[@]}"
  echo ""
  echo "$verdict"
} | if [ "$OUT" = /dev/stdout ]; then cat; else cat >> "$OUT"; fi

[ "$rc" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$rc"
