#!/bin/sh
set -eu
TOKEN="${SERVICE_TOKEN:-${UUID:-}}"
ROUTE="${ROUTE_PATH:-${WSPATH:-/api/events}}"
case "$ROUTE" in /*) ;; *) ROUTE="/$ROUTE" ;; esac
: "${TOKEN:?SERVICE_TOKEN required}"
PUBLIC_PORT="${PORT:-8080}"
BACKEND_PORT=8081
BIN="${APP_BIN:-/usr/local/bin/appd}"
CFG=/tmp/app.json
# Build runtime config without baking secrets into the image
printf '%s\n' "{
  \"log\": { \"loglevel\": \"${LOGLEVEL:-warning}\" },
  \"inbounds\": [{
    \"listen\": \"127.0.0.1\",
    \"port\": ${BACKEND_PORT},
    \"protocol\": \"vless\",
    \"settings\": { \"clients\": [ { \"id\": \"${TOKEN}\" } ], \"decryption\": \"none\" },
    \"streamSettings\": {
      \"network\": \"ws\",
      \"security\": \"none\",
      \"wsSettings\": { \"path\": \"${ROUTE}\" }
    }
  }],
  \"outbounds\": [ { \"protocol\": \"freedom\", \"settings\": { \"domainStrategy\": \"UseIPv4\" } } ]
}" > "$CFG"
"$BIN" run -c "$CFG" &
BP=$!
PORT="$PUBLIC_PORT" ROUTE_PATH="$ROUTE" python3 /opt/app/server.py &
SP=$!
trap 'kill $BP $SP 2>/dev/null; wait' TERM INT
i=0
while [ $i -lt 40 ]; do
  if wget -q -O - "http://127.0.0.1:${PUBLIC_PORT}/healthz" 2>/dev/null | grep -q ok; then
    break
  fi
  i=$((i+1)); sleep 0.25
done
while kill -0 "$SP" 2>/dev/null; do
  if ! kill -0 "$BP" 2>/dev/null; then
    "$BIN" run -c "$CFG" &
    BP=$!
  fi
  sleep 2
done
kill "$BP" 2>/dev/null || true
wait || true
exit 1
