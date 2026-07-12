#!/bin/bash
# Prepare an ephemeral system to smoke-test the seafile-server package: add the runtime repo
# (which also provides libsearpc) and install the freshly-built seafile-server .deb.
#
# DESTRUCTIVE - installs packages. Meant for an ephemeral CI container/VM, never a real install.
#
# Install source (first argument):
#   * artifacts <DIR>  -> install the freshly-built .deb files in <DIR>
#   * apt              -> apt-get install seafile-server (latest published)
#
# Usage:  prepare.sh artifacts <DIR>
#         prepare.sh apt
set -eu
export DEBIAN_FRONTEND=noninteractive
info()  { printf '\n========== %s ==========\n' "$1"; }
error() { local code="$1"; shift; echo "$*" >&2; exit "$code"; }
MODE="${1:-}"; ARTIFACTS=""
case "$MODE" in
  artifacts) ARTIFACTS="${2:-}"; [ -n "$ARTIFACTS" ] || error 2 "usage: prepare.sh artifacts <DIR>" ;;
  apt) ;;
  *) error 2 "usage: prepare.sh {artifacts <DIR>|apt}" ;;
esac
. /etc/os-release
[ -d /run/systemd/system ] || error 4 "systemd is not running (/run/systemd/system missing)"
install -d -m 0755 /etc/apt/keyrings

info "Runtime repo (apt.crunchy.run/seafile) - provides libsearpc and runtime deps"
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg
curl -fsSL https://apt.crunchy.run/seafile/install.sh | bash -
apt-get update -qq

info "Install the seafile stack [mode: $MODE]"
if [ "$MODE" = artifacts ]; then
  arch="$(dpkg --print-architecture)"
  # install this arch's binaries (libsearpc, seafile-server, seahub) plus the
  # arch-independent seafile metapackage (only built on the primary arch).
  mapfile -t debs < <(ls "$ARTIFACTS"/*_"$arch".deb "$ARTIFACTS"/*_all.deb 2>/dev/null)
  [ "${#debs[@]}" -gt 0 ] || error 1 "no matching .deb files (arch=$arch) in $ARTIFACTS"
  printf '  %s\n' "${debs[@]}"
  apt-get install -y "${debs[@]}"
else
  apt-get install -y seafile
fi
echo "--- installed ---"; dpkg -l 'seafile*' 'libsearpc*' | awk '/^ii/{print $2, $3}'

info "Start services"
systemctl start seafile.service || true
systemctl start seahub.service || true

info "DONE"
