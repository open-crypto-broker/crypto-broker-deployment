#!/bin/sh
# CF entrypoint: starts the static Go reverse proxy on $PORT, then hands off
# to the original LGTM stack (Prometheus, Loki, Tempo, OTel Collector, Grafana).
# CF injects $PORT at runtime; the proxy routes:
#   /v1/*  → OTLP HTTP collector (localhost:4318)
#   /*     → Grafana UI          (localhost:3000)
set -e

echo "[cf-entrypoint] Starting CF proxy on PORT=${PORT}"
/cf-proxy &

# Tempo watchdog: run-all.sh does not restart crashed services, so we poll
# Tempo's /ready endpoint and re-launch run-tempo.sh if it goes down.
# Runs in background before exec so it survives the exec call below.
(
  echo "[cf-entrypoint] Tempo watchdog started (initial wait 120s)"
  sleep 120
  while true; do
    if curl -sf http://127.0.0.1:3200/ready >/dev/null 2>&1; then
      sleep 30
    else
      echo "[cf-entrypoint] Tempo not ready — restarting"
      (cd /otel-lgtm && ./run-tempo.sh) &
      sleep 90
    fi
  done
) &

# Loki watchdog: same pattern — poll /ready and re-launch run-loki.sh on crash.
(
  echo "[cf-entrypoint] Loki watchdog started (initial wait 120s)"
  sleep 120
  while true; do
    if curl -sf http://127.0.0.1:3100/ready >/dev/null 2>&1; then
      sleep 30
    else
      echo "[cf-entrypoint] Loki not ready — restarting"
      (cd /otel-lgtm && ./run-loki.sh) &
      sleep 90
    fi
  done
) &

echo "[cf-entrypoint] Starting LGTM stack from /otel-lgtm/ (run-all.sh uses relative paths)"
# run-all.sh calls ./run-grafana.sh, ./run-loki.sh etc with relative paths,
# so it MUST be executed with /otel-lgtm/ as the working directory.
cd /otel-lgtm
exec ./run-all.sh
