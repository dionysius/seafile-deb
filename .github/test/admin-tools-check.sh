#!/bin/bash
# Smoke-test the admin/maintenance tools (seaf-gc, seaf-fsck, seahub-reset-admin):
# each must refuse while the seafile stack is active, and actually work once it
# isn't. Run after boot-check.sh has confirmed a healthy stack. Leaves seafile
# and seahub running again on exit either way.
#
# Runs IN PLACE as root, requires systemd - ephemeral testbed only.
#
# Usage: admin-tools-check.sh [--out FILE]
set -u
OUT="${OUT:-/dev/stdout}"
info()  { printf '\n========== %s ==========\n' "$1"; }
error() { local code="$1"; shift; echo "$*" >&2; exit "$code"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) error 2 "unknown option: $1" ;;
  esac
done
[ -d /run/systemd/system ] || error 4 "systemd is not running (/run/systemd/system missing)"

rc=0; rows=()
trap 'systemctl start seafile.service seahub.service >/dev/null 2>&1 || true' EXIT

check_refuses_while_active() {
  local tool="$1" out
  out=$("$tool" 2>&1) && { echo "FAIL: $tool did not refuse"; echo "$out"; rc=1; rows+=("| \`$tool\` refuses while the stack is active | ❌ |"); return; }
  if grep -q "seafile.service is running" <<<"$out"; then
    echo "OK: $tool refused"
    rows+=("| \`$tool\` refuses while the stack is active | ✅ |")
  else
    echo "FAIL: $tool refused for the wrong reason"; echo "$out"
    rc=1; rows+=("| \`$tool\` refuses while the stack is active | ❌ |")
  fi
}

info "seaf-gc / seaf-fsck refuse while seafile.service is active"
check_refuses_while_active seaf-gc
check_refuses_while_active seaf-fsck

info "Stop the stack, run seaf-gc and seaf-fsck for real"
systemctl stop seahub.service seafile.service

out=$(seaf-gc 2>&1)
if grep -q "GC is finished" <<<"$out"; then
  echo "OK: seaf-gc completed"; rows+=("| \`seaf-gc\` runs to completion | ✅ |")
else
  echo "FAIL: seaf-gc"; echo "$out"; rc=1; rows+=("| \`seaf-gc\` runs to completion | ❌ |")
fi

out=$(seaf-fsck 2>&1)
if grep -q "Fsck finished" <<<"$out"; then
  echo "OK: seaf-fsck completed"; rows+=("| \`seaf-fsck\` runs to completion | ✅ |")
else
  echo "FAIL: seaf-fsck"; echo "$out"; rc=1; rows+=("| \`seaf-fsck\` runs to completion | ❌ |")
fi

info "Object store stays seafile-owned after seaf-gc/seaf-fsck ran as root"
data_dir=$(set -a; . /etc/seafile/seafile.env; echo "$SEAFILE_DATA_DIR")
stray=$(find "$data_dir" -not -user seafile -print -quit 2>/dev/null)
if [ -z "$stray" ]; then
  echo "OK: no non-seafile-owned files"; rows+=("| object store stays seafile-owned | ✅ |")
else
  echo "FAIL: found $stray"; rc=1; rows+=("| object store stays seafile-owned | ❌ |")
fi

info "seahub-reset-admin creates an account non-interactively"
systemctl start seafile.service
sleep 3
out=$(seahub-reset-admin --noinput --username=citest --email=citest@example.com --password=citest-password-123 2>&1)
if grep -q "Superuser created successfully" <<<"$out"; then
  echo "OK: account created"; rows+=("| \`seahub-reset-admin\` creates an account | ✅ |")
else
  echo "FAIL: seahub-reset-admin"; echo "$out"; rc=1; rows+=("| \`seahub-reset-admin\` creates an account | ❌ |")
fi

info "Summary"
[ "$rc" -eq 0 ] && verdict="✅ admin tools: refuse while active, work once the stack is stopped, keep correct ownership" \
                || verdict="❌ admin tools: see failures above"
[ "$OUT" = /dev/stdout ] || mkdir -p "$(dirname "$OUT")"
{
  echo ""
  echo "| Admin tool check | Result |"
  echo "|---|---|"
  printf '%s\n' "${rows[@]}"
  echo ""
  echo "$verdict"
} | if [ "$OUT" = /dev/stdout ]; then cat; else cat >> "$OUT"; fi

[ "$rc" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$rc"
