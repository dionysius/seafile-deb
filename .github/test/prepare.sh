#!/bin/bash
# Prepare an ephemeral system to smoke-test the seafile stack, then start the services.
#
# DESTRUCTIVE - installs packages. Meant for an ephemeral CI container/VM, never a real install.
#
# Install source (first argument):
#   * artifacts <DIR>  -> install the freshly-built .deb files in <DIR> (the CI pipeline)
#   * apt              -> add the published repo and apt-get install seafile-server (latest published)
#
# The artifacts path needs no external seafile repo: seafile-server (with its bundled python
# venv) comes from the build, and every remaining dependency (python3, redis, libsearpc, the
# shlibs-resolved system libraries) is a standard distro package.
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
[ -d /run/systemd/system ] || error 4 "systemd is not running (/run/systemd/system missing)"
apt-get update -qq
# curl: the boot-check HTTP gate needs it (and the apt-mode repo bootstrap below)
apt-get install -y -qq curl ca-certificates

info "Install the seafile stack [mode: $MODE]"
if [ "$MODE" = artifacts ]; then
  # Install this arch's binaries plus the arch-independent data package (only
  # built on the primary arch); their Depends resolve from the archive.
  arch="$(dpkg --print-architecture)"
  mapfile -t debs < <(ls "$ARTIFACTS"/*_"$arch".deb "$ARTIFACTS"/*_all.deb 2>/dev/null)
  [ "${#debs[@]}" -gt 0 ] || error 1 "no matching .deb files (arch=$arch) in $ARTIFACTS"
  printf '  %s\n' "${debs[@]}"
  apt-get install -y "${debs[@]}"
else
  install -d -m 0755 /etc/apt/keyrings
  apt-get install -y -qq gnupg
  curl -fsSL https://apt.crunchy.run/seafile/install.sh | bash -
  apt-get update -qq
  apt-get install -y seafile-server
fi
echo "--- installed ---"; dpkg -l 'seafile*' 'libsearpc*' | awk '/^ii/{print $2, $3}'

info "Start services (seahub and seaf-server pull in the seafile-migrate one-shot)"
systemctl start seaf-server.service seahub.service || true

info "DONE"
