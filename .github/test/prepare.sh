#!/bin/bash
# Prepare an ephemeral system to smoke-test the seafile stack, then start the services.
#
# DESTRUCTIVE - installs packages. Meant for an ephemeral CI container/VM.
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

info "Provision the database and secrets (normally done by the admin, see the wiki)"
apt-get install -y -qq mariadb-server openssl
systemctl start mariadb.service
DBPW=$(openssl rand -hex 16)
mysql <<SQL
CREATE DATABASE ccnet_db CHARACTER SET utf8mb4;
CREATE DATABASE seafile_db CHARACTER SET utf8mb4;
CREATE DATABASE seahub_db CHARACTER SET utf8mb4;
CREATE USER 'seafile'@'127.0.0.1' IDENTIFIED BY '$DBPW';
GRANT ALL PRIVILEGES ON ccnet_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'127.0.0.1';
GRANT ALL PRIVILEGES ON seahub_db.* TO 'seafile'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
sed -i \
  -e "s|^SEAFILE_MYSQL_DB_PASSWORD=$|SEAFILE_MYSQL_DB_PASSWORD=$DBPW|" \
  -e "s|^JWT_PRIVATE_KEY=$|JWT_PRIVATE_KEY=$(openssl rand -hex 32)|" \
  /etc/seafile/seafile.env
sed -i "s|^SECRET_KEY = \"\"|SECRET_KEY = \"$(openssl rand -hex 32)\"|" /etc/seafile/seahub_settings.py

info "Start services (seahub and seafile pull in the seafile-migrate one-shot)"
systemctl start seafile.service seahub.service || true

info "DONE"
