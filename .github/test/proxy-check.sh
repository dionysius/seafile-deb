#!/bin/bash
# Exercise the stack through the shipped nginx example (/usr/share/doc/seafile-server/examples)
# with a self-signed certificate under a local hostname: browser-style login (CSRF needs Host
# and X-Forwarded-Proto), every asset of the login and library pages, an upload and download
# through /seafhttp, a thumbnail, and the notification websocket upgrade. Run after
# boot-check.sh; sets the public address in seafile.env and restarts the stack.
#
# Runs IN PLACE as root, requires systemd - ephemeral testbed only.
#
# Usage: proxy-check.sh [--out FILE]
set -u
OUT="${OUT:-/dev/stdout}"
HOST=seafile.example.com
B="https://$HOST"
info()  { printf '\n========== %s ==========\n' "$1"; }
error() { local code="$1"; shift; echo "$*" >&2; exit "$code"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) error 2 "unknown option: $1" ;;
  esac
done
[ -d /run/systemd/system ] || error 4 "systemd is not running (/run/systemd/system missing)"
export DEBIAN_FRONTEND=noninteractive
rc=0; rows=()
ok()   { echo "OK   $1"; rows+=("| $1 | ✅ |"); }
fail() { echo "FAIL $1${2:+: $2}"; rows+=("| $1 | ❌ |"); rc=1; }
http() { curl -sS -k -o /dev/null -w '%{http_code}' --max-time 30 "$@" 2>/dev/null || echo 000; }

info "Install nginx with the shipped example"
apt-get install -y -qq nginx ssl-cert >/dev/null
grep -q "$HOST" /etc/hosts || echo "127.0.0.1 $HOST" >> /etc/hosts
sed -e "s|/etc/letsencrypt/live/$HOST/fullchain.pem|/etc/ssl/certs/ssl-cert-snakeoil.pem|" \
    -e "s|/etc/letsencrypt/live/$HOST/privkey.pem|/etc/ssl/private/ssl-cert-snakeoil.key|" \
    /usr/share/doc/seafile-server/examples/nginx/seafile.conf > /etc/nginx/sites-available/seafile
rm -f /etc/nginx/sites-enabled/default
ln -sf ../sites-available/seafile /etc/nginx/sites-enabled/seafile
nginx -t 2>&1 | tail -1
systemctl restart nginx

info "Point seafile at the public address and restart"
sed -i -e "s|^SEAFILE_SERVER_PROTOCOL=.*|SEAFILE_SERVER_PROTOCOL=https|" \
       -e "s|^SEAFILE_SERVER_HOSTNAME=.*|SEAFILE_SERVER_HOSTNAME=$HOST|" \
       -e "s|^NOTIFICATION_SERVER_URL=.*|NOTIFICATION_SERVER_URL=wss://$HOST/notification|" /etc/seafile/seafile.env
systemctl restart seafile.service seafile-fileserver.service seafile-notification.service seahub.service
for i in $(seq 1 30); do [ "$(http "$B/accounts/login/")" = 200 ] && break; sleep 2; done

info "Account for the checks"
out=$(seahub-reset-admin --noinput --username=proxytest --email=proxytest@example.com --password=proxytest-password-123 2>&1) \
  || grep -q DuplicatedContactEmailError <<<"$out" \
  && ok "seahub-reset-admin creates the test account" || fail "seahub-reset-admin creates the test account" "$(tail -n 1 <<<"$out")"

info "Browser-style login (Origin header, needs Host + X-Forwarded-Proto)"
cj=$(mktemp)
http -c "$cj" "$B/accounts/login/" >/dev/null
csrf=$(awk '/sfcsrftoken/{print $7}' "$cj")
code=$(http -b "$cj" -c "$cj" -H "Origin: $B" -e "$B/accounts/login/" \
  -d "login=proxytest@example.com&password=proxytest-password-123&csrfmiddlewaretoken=$csrf" "$B/accounts/login/")
[ "$code" = 302 ] && grep -q sessionid "$cj" && ok "login through the proxy" || fail "login through the proxy" "HTTP $code"

info "Every asset referenced by the login and library pages"
bad=0; n=0
for page in /accounts/login/ /libraries/; do
  curl -sSk -b "$cj" -L -o /tmp/page.html "$B$page"
  for u in $(grep -oE '(src|href)="/media/[^"]+"' /tmp/page.html | sed -E 's/^(src|href)="//; s/"$//' | sort -u); do
    n=$((n+1)); c=$(http -b "$cj" "$B$u"); [ "$c" = 200 ] || { bad=$((bad+1)); echo "  $c $u"; }
  done
done
[ "$n" -gt 0 ] && [ "$bad" = 0 ] && ok "$n assets load" || fail "assets load" "$bad of $n failing"

info "Upload and download through /seafhttp"
T=$(curl -sSk -d "username=proxytest@example.com&password=proxytest-password-123" "$B/api2/auth-token/" | sed -E 's/.*"token": ?"([^"]+)".*/\1/')
RID=$(curl -sSk -H "Authorization: Token $T" -d "name=proxytest" "$B/api2/repos/" | grep -oE '"repo_id": ?"[0-9a-f-]{36}"' | grep -oE '[0-9a-f-]{36}')
UL=$(curl -sSk -H "Authorization: Token $T" "$B/api2/repos/$RID/upload-link/" | tr -d '"')
head -c 65536 /dev/urandom > /tmp/proxytest.bin
code=$(http -H "Authorization: Token $T" -F file=@/tmp/proxytest.bin -F parent_dir=/ "$UL")
[ "$code" = 200 ] && ok "upload via /seafhttp" || fail "upload via /seafhttp" "HTTP $code (link $UL)"
DL=$(curl -sSk -H "Authorization: Token $T" "$B/api2/repos/$RID/file/?p=/proxytest.bin" | tr -d '"')
curl -sSk -o /tmp/proxytest.out "$DL" && cmp -s /tmp/proxytest.bin /tmp/proxytest.out && ok "download via /seafhttp" || fail "download via /seafhttp" "$DL"

info "Thumbnail"
/usr/lib/seahub/venv/bin/python -c "from PIL import Image; Image.new('RGB',(64,64),(200,30,30)).save('/tmp/proxytest.png')"
http -H "Authorization: Token $T" -F file=@/tmp/proxytest.png -F parent_dir=/ "$UL" >/dev/null
code=$(http -b "$cj" "$B/thumbnail/$RID/256/proxytest.png")
[ "$code" = 200 ] && ok "thumbnail" || fail "thumbnail" "HTTP $code"

info "Notification websocket"
code=$(curl -sSk -o /dev/null -w '%{http_code}' --max-time 3 --http1.1 -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" "$B/notification/" 2>/dev/null)
[ "$code" = 101 ] && ok "websocket upgrade via /notification" || fail "websocket upgrade via /notification" "HTTP $code"

if [ "$rc" != 0 ]; then
  echo "--- nginx error log ---"; tail -n 30 /var/log/nginx/error.log 2>/dev/null || true
  echo "--- seahub journal ---"; journalctl -u seahub.service --no-pager -n 40 || true
fi

info "Summary"
[ "$rc" -eq 0 ] && verdict="✅ proxy: login, assets, transfer, thumbnail and websocket work through the shipped nginx example" \
                || verdict="❌ proxy: see failures above"
[ "$OUT" = /dev/stdout ] || mkdir -p "$(dirname "$OUT")"
{
  echo ""
  echo "| Proxy check (nginx example) | Result |"
  echo "|---|---|"
  printf '%s\n' "${rows[@]}"
  echo ""
  echo "$verdict"
} | if [ "$OUT" = /dev/stdout ]; then cat; else cat >> "$OUT"; fi

[ "$rc" -eq 0 ] && echo "RESULT: PASS" || echo "RESULT: FAIL"
exit "$rc"
