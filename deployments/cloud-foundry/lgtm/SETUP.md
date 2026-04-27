# CF LGTM Observability Stack — Setup & Troubleshooting Guide

This document records the full process of making the Grafana LGTM observability
stack work with the CryptoBroker CF deployment. It covers both the **ngrok**
(Option A) and **CF-hosted LGTM** (Option B) approaches, including every problem
encountered and how it was fixed.

---

## The Problem

The CF CLI apps (`crypto-broker-go-cli`, `crypto-broker-js-cli`) include an
OpenTelemetry Collector sidecar that exports traces, logs, and metrics via OTLP
HTTP. That sidecar needs a reachable HTTPS endpoint to push to.

The `grafana/otel-lgtm` stack (Prometheus + Loki + Tempo + Grafana + OTel
Collector, all in one container) runs locally on the developer laptop. CF apps
cannot reach `localhost` directly.

### Option A — ngrok (dev fallback)

Run a local ngrok tunnel to expose the laptop's LGTM OTLP port to the internet
so that CF apps can reach it over HTTPS.

#### Step 1 — Create a free ngrok account

1. Go to <https://ngrok.com> and sign up for a free account.
2. After signing in, open the [Your Authtoken](https://dashboard.ngrok.com/get-started/your-authtoken) page and copy your authtoken.

#### Step 2 — Install the ngrok CLI

```bash
# macOS (Homebrew)
brew install ngrok

# Verify
ngrok version
```

#### Step 3 — Authenticate the CLI

```bash
ngrok config add-authtoken <your-authtoken>
```

This writes the token to `~/.config/ngrok/ngrok.yml` so every subsequent
`ngrok` invocation is authenticated automatically.

#### Step 4 — Start the local LGTM stack

```bash
docker compose -f deployments/docker/lgtm/docker-compose.yaml up -d
```

#### Step 5 — Open the ngrok tunnel

```bash
ngrok http 4318
```

ngrok prints a forwarding URL like:

```
Forwarding  https://a1b2c3d4.ngrok-free.app -> http://localhost:4318
```

Keep this terminal open — closing it stops the tunnel.

#### Step 6 — Update the CLI app manifests

In both `deployments/cloud-foundry/go/manifest.yaml` and
`deployments/cloud-foundry/js/manifest.yaml`, set the forwarding URL:

```yaml
env:
  OTEL_COLLECTOR_ENDPOINT: "https://a1b2c3d4.ngrok-free.app"
```

#### Step 7 — Redeploy the CLI apps

```bash
cf push --manifest deployments/cloud-foundry/go/manifest.yaml
cf push --manifest deployments/cloud-foundry/js/manifest.yaml
```

**Limitations:**
- The dev domain URL is **stable** — it is permanently assigned to your account and does not change across tunnel restarts. However, you still need to restart `ngrok http 4318` manually after a laptop sleep or reboot; the CLI apps keep sending to the same URL, which will simply queue or drop until the tunnel is back up.
- The tunnel goes down automatically when the laptop sleeps, the terminal is closed, or ngrok restarts — unlike Option B, there is no always-on recovery.
- Free tier rate limit is 4,000 HTTP requests/min across all endpoints, and 20,000 HTTP/S requests per month total — high-volume telemetry can exhaust the monthly quota quickly.
- Not suitable for continuous or unattended collection.

### Option B — CF-hosted LGTM app (chosen approach)

Deploy the entire LGTM stack as a Docker-based CF app. CF apps can reach it
24/7 over a stable HTTPS route with no tunnel required.

**Limitations:**
- **No data persistence.** All telemetry (traces, logs, metrics) is stored inside the container's ephemeral filesystem. A CF app restart, redeploy, or crash wipes all collected data — there is no external storage backend.
- **Disk quota caps retention.** The 4 GB disk quota limits how many Tempo WAL blocks, Loki chunks, and Prometheus TSDB samples can accumulate. Old data is evicted once the disk fills up. Expect roughly 24-48 hours of trace/log retention under normal CLI traffic.
- **Memory constrained.** The 2 GB memory limit is shared across Grafana, Loki, Tempo, Prometheus, and the OTel Collector. A sudden burst of high-cardinality traces or a Tempo WAL replay can push usage toward the limit; exceeding it causes the whole app to be killed by CF.
- **Single instance, no HA.** `instances: 1` in `manifest.yaml`. Any CF restart (OOM kill, platform maintenance, redeploy) causes a short downtime of 60-120 s while all components start up again. Traces sent during this window are dropped.
- **~90 s trace gap on Tempo watchdog restart.** The Tempo watchdog waits 90 s after relaunching `run-tempo.sh` before polling again. Spans arriving during that window are accepted by the OTel Collector but immediately dropped because Tempo's ingest port `:3200` is not yet ready.
- **Unauthenticated OTLP endpoint.** The `/v1/*` route is open — anyone who knows the CF app URL can push arbitrary traces, logs, and metrics. There is no token or mTLS on the OTel Collector ingest path.
- **Admin password in CF environment.** `GF_SECURITY_ADMIN_PASSWORD` is stored as a CF environment variable, visible to any CF user who can run `cf env crypto-broker-lgtm` in the same org/space.
- **Shared LGTM image.** The Docker image is public on Docker Hub. Rebuilding and redeploying is required for any config change to `tempo-config.yaml`, `entrypoint.sh`, or the dashboard.

---

## Option B Implementation

### Architecture

#### Component overview

A high-level view of what runs where and how traffic flows between them:

```
CLI app (Go/JS)
  └── OTel Collector sidecar
        │
        │  HTTPS  /v1/traces, /v1/metrics, /v1/logs
        ▼
crypto-broker-lgtm CF app   (single PORT, single route)
  ├── cf-proxy (Go)          ← listens on $PORT (CF-assigned)
  │     ├── /v1/*  → 127.0.0.1:4318  (OTel Collector OTLP HTTP)
  │     └── /*     → 127.0.0.1:3000  (Grafana UI)
  └── grafana/otel-lgtm
        ├── Grafana      :3000
        ├── Loki         :3100
        ├── Tempo        :3200  (OTLP grpc :4417, http :4418)
        ├── Prometheus   :9090
        ├── OTel Collector :4317/:4318
        └── Pyroscope    :4040
```

CF only exposes a single port per app (injected as `$PORT`). The Go proxy
bridges that single external port to the two internal services.

#### Infrastructure view

A detailed view of the CF platform boundary, port bindings, and routing logic:

CF gives every app exactly one external port, injected as `$PORT` at runtime.
The entire LGTM stack runs inside a single container and binds its services to
loopback ports only. A small static Go binary (`cf-proxy`) is the sole process
that listens on `$PORT` and routes traffic inward.

```
┌─ CF Platform ────────────────────────────────────────────────────────────────┐
│  Route: crypto-broker-lgtm.<cf_domain>  (port 443, public HTTPS)             │
│  ↓ TLS termination by CF Gorouter                                            │
│  ↓ forwarded to container $PORT (HTTP)                                       │
│                                                                              │
│  ┌─ Container: crypto-broker-lgtm ───────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  /cf-proxy   ← listens on 0.0.0.0:$PORT                               │   │
│  │    │                                                                  │   │
│  │    ├─ path starts with /v1/  ──► 127.0.0.1:4318  OTel Collector       │   │
│  │    │       (traces, metrics,            ↓                             │   │
│  │    │        logs via OTLP HTTP)     fans out to:                      │   │
│  │    │                               Tempo   :3200  (traces)            │   │
│  │    │                               Loki    :3100  (logs)              │   │
│  │    │                               Prometheus:9090 (metrics)          │   │
│  │    │                                                                  │   │
│  │    └─ all other paths  ─────────► 127.0.0.1:3000  Grafana UI          │   │
│  │                                                                       │   │
│  │  grafana/otel-lgtm processes (all on loopback):                       │   │
│  │    Grafana       :3000   UI + datasource queries                      │   │
│  │    Loki          :3100   log storage / query                          │   │
│  │    Tempo         :3200   trace storage / query                        │   │
│  │    Prometheus    :9090   metric storage / query                       │   │
│  │    OTel Collector:4317 (gRPC), :4318 (HTTP)  ingest endpoint          │   │
│  │    Pyroscope     :4040   continuous profiling (unused here)           │   │
│  │    Tempo watchdog (shell loop in entrypoint.sh)                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
         ▲                                            ▲
         │  HTTPS /v1/traces|metrics|logs             │  HTTPS /*
         │  (OTLP HTTP, from CF CLI apps)             │  (browser)

   crypto-broker-go-cli                         Developer
   crypto-broker-js-cli
     └── OTel Collector sidecar
```

#### Request flows

**Telemetry push** (CLI app → LGTM):
```
CF CLI app OTel sidecar
  → POST https://crypto-broker-lgtm.<cf_domain>/v1/traces   (HTTPS, CF Gorouter)
  → cf-proxy ($PORT)          path starts with /v1/
  → OTel Collector 127.0.0.1:4318
  → Tempo 127.0.0.1:3200      (traces)
  → Loki  127.0.0.1:3100      (logs)
  → Prometheus 127.0.0.1:9090 (metrics)
```

**Grafana UI** (browser → LGTM):
```
Browser
  → GET https://crypto-broker-lgtm.<cf_domain>/   (HTTPS, CF Gorouter)
  → cf-proxy ($PORT)          all other paths
  → Grafana 127.0.0.1:3000
```

#### Container startup sequence

```
CF starts container → /cf-entrypoint.sh
  1. cf-proxy starts (background)            — immediately accepts connections on $PORT
  2. Tempo watchdog starts (background)      — waits 120 s, then polls :3200/ready every 30 s
  3. cd /otel-lgtm && exec run-all.sh        — sequentially starts:
       run-otelcol.sh   OTel Collector
       run-loki.sh      Loki
       run-tempo.sh     Tempo
       run-prometheus.sh Prometheus
       run-grafana.sh   Grafana           (~60-90 s until UI is ready)
```

During startup `cf-proxy` returns `HTTP 503` with `Retry-After: 10` for any
request that cannot reach an upstream — this is intentional so CLI apps back
off gracefully while Grafana/OTel Collector initialise.

### File Structure

The `deployments/cloud-foundry/lgtm/` directory contains everything specific to
the CF deployment. The `docker build` command must be run from the parent
`deployments/` directory so the Dockerfile can also reference the shared
dashboard JSON from `docker/lgtm/`.

```
deployments/
├── docker/
│   └── lgtm/observability/grafana/provisioning/dashboards/
│       └── cryptobroker-overview.json  ← shared dashboard, referenced by Dockerfile
│
└── cloud-foundry/lgtm/                 ← all CF-LGTM–specific files live here
    │
    ├── Dockerfile                      # Two-stage build:
    │                                   #   stage 1 (golang:1.24-alpine): compile cf-proxy
    │                                   #   stage 2 (grafana/otel-lgtm): embed proxy +
    │                                   #     tempo-config.yaml + dashboard JSON (UID remapped)
    │
    ├── entrypoint.sh                   # Container CMD; three responsibilities:
    │                                   #   1. launch cf-proxy in background
    │                                   #   2. launch Tempo watchdog loop in background
    │                                   #   3. exec /otel-lgtm/run-all.sh (CWD must be /otel-lgtm/)
    │
    ├── proxy/
    │   └── main.go                     # Static Go reverse proxy (~50 lines)
    │                                   # Routing rule: /v1/* → :4318, /* → :3000
    │                                   # Uses 127.0.0.1 (not localhost) to avoid IPv6 bind mismatch
    │                                   # Returns 503 + Retry-After on upstream error
    │
    ├── tempo-config.yaml               # Overrides image defaults (1 s blocks → 2 min blocks)
    │                                   # Prevents WAL explosion under sustained trace load
    │                                   # Baked in at: /otel-lgtm/tempo-config.yaml
    │
    ├── grafana/
    │   ├── datasources/                # (empty — datasources are provisioned by the base image)
    │   └── provisioning/
    │       └── dashboards/
    │           └── dashboards.yaml     # Grafana dashboard-loader config
    │                                   # Points at /otel-lgtm/grafana/conf/provisioning/dashboards/
    │                                   # so both our dashboard and image built-ins are loaded
    │
    ├── manifest.yaml                   # cf push manifest; key settings:
    │                                   #   docker.image: ((docker_image))   — from vars.yaml
    │                                   #   memory: 2G / disk: 4G
    │                                   #   health-check-type: process        — not http
    │                                   #   GF_SERVER_ROOT_URL, GF_SECURITY_ADMIN_PASSWORD
    │
    ├── vars.yaml.example               # Template for secrets — copy to vars.yaml
    ├── vars.yaml                       # Actual secrets (gitignored): docker_image,
    │                                   #   cf_domain, grafana_admin_password
    │
    ├── Taskfile.yaml                   # Tasks: lgtm-build, lgtm-push, lgtm-deploy,
    │                                   #        lgtm-build-push-deploy, lgtm-logs, lgtm-status
    │
    └── nginx.conf.template             # Leftover from an earlier nginx-based prototype
                                        # Not used — the Go proxy replaced nginx
```

#### How the Dockerfile stitches it together

```
Stage 1 — proxy-builder (golang:1.24-alpine)
  COPY proxy/main.go → compile → /cf-proxy  (CGO_ENABLED=0, fully static)

Stage 2 — final image (grafana/otel-lgtm:latest, linux/amd64)
  COPY /cf-proxy              → /cf-proxy
  COPY tempo-config.yaml      → /otel-lgtm/tempo-config.yaml   (overrides image default)
  COPY cryptobroker-overview.json → /otel-lgtm/.../dashboards/ (then sed to remap UIDs)
  COPY dashboards.yaml        → /otel-lgtm/.../dashboards/cryptobroker-dashboards.yaml
  COPY entrypoint.sh          → /cf-entrypoint.sh   (chmod +x)
  CMD  ["/cf-entrypoint.sh"]
```

---

## Problems Encountered and Fixes

### 1. No package manager in the base image

`grafana/otel-lgtm:latest` is based on RHEL 9. Neither `apt-get` nor `apk` is
available. Installing nginx or any binary at build time with `RUN apt-get` fails
immediately.

**Fix:** Use a multi-stage Docker build. Compile a fully static Go reverse proxy
in `golang:1.24-alpine` (stage 1), then copy only the binary into the LGTM
image (stage 2). No package manager needed.

```dockerfile
FROM --platform=linux/amd64 golang:1.24-alpine AS proxy-builder
WORKDIR /src
COPY cloud-foundry/lgtm/proxy/main.go .
RUN go mod init cfproxy && CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /cf-proxy .

FROM --platform=linux/amd64 grafana/otel-lgtm:latest
COPY --from=proxy-builder /cf-proxy /cf-proxy
```

### 2. `exec format error` on CF — ARM vs AMD64

Building on Apple Silicon (M-series Mac) produces an ARM image by default. CF
runs on `linux/amd64`. The container start fails with `exec format error`.

**Fix:** Pin both `FROM` stages and the `docker build` command to
`--platform linux/amd64`.

```bash
docker build --platform linux/amd64 -f cloud-foundry/lgtm/Dockerfile -t <image> .
```

### 3. Health check timeout — app always shows `starting`

With `health-check-type: http`, CF polls the app's HTTP endpoint during startup.
Grafana takes 60-90 seconds to initialize. CF times out and marks the app
as crashed before Grafana is ready.

**Fix:** Use `health-check-type: process`. CF considers the app healthy as long
as the entrypoint process stays running, regardless of HTTP readiness.

```yaml
# manifest.yaml
health-check-type: process
```

### 4. 502 error — `run-all.sh` uses relative paths

The image's `run-all.sh` calls `./run-grafana.sh`, `./run-loki.sh`, etc. using
relative paths. If the working directory is not `/otel-lgtm/` when it executes,
it cannot find any of the component scripts and dies immediately.

**Fix:** Change directory before `exec`-ing `run-all.sh`.

```sh
# entrypoint.sh
cd /otel-lgtm
exec ./run-all.sh
```

### 5. 502 error — proxy used `localhost` (resolved to IPv6 `[::1]`)

The Go proxy originally targeted `localhost:3000` and `localhost:4318`. On the
CF container, `localhost` resolves to `[::1]` (IPv6), but Grafana and the OTel
Collector only bind on `127.0.0.1` (IPv4), so every connection was refused.

**Fix:** Use `127.0.0.1` explicitly in all proxy targets.

```go
// proxy/main.go
otlp    := newProxy("http://127.0.0.1:4318")
grafana := newProxy("http://127.0.0.1:3000")
```

### 6. Grafana crash — duplicate datasource provisioning

The custom `datasources.yaml` added UIDs `prometheus`, `loki`, `tempo`.
The `grafana/otel-lgtm` image already provisions datasources with those exact
UIDs at `/otel-lgtm/grafana/conf/provisioning/datasources/`. Grafana detects the
conflict on startup and exits with:

```
Datasource provisioning error: data source not found
```

**Fix:** Remove the custom `datasources.yaml` entirely and let the image's
built-in provisioning handle datasources. Update the dashboard JSON to use the
image's UIDs (`prometheus`, `loki`, `tempo`) instead of the local Docker UIDs
(`prometheus-lgtm`, `loki-lgtm`, `tempo-lgtm`).

```dockerfile
# Dockerfile — remap UIDs at build time with sed
COPY docker/lgtm/observability/grafana/provisioning/dashboards/cryptobroker-overview.json \
     /otel-lgtm/grafana/conf/provisioning/dashboards/cryptobroker-overview.json
RUN sed -i \
        -e 's/prometheus-lgtm/prometheus/g' \
        -e 's/loki-lgtm/loki/g' \
        -e 's/tempo-lgtm/tempo/g' \
    /otel-lgtm/grafana/conf/provisioning/dashboards/cryptobroker-overview.json
```

The dashboard loader config (`dashboards.yaml`) points to the directory, not a
specific file, so both the image's built-in dashboards and ours are loaded:

```yaml
# grafana/provisioning/dashboards/dashboards.yaml
providers:
  - name: 'CryptoBroker Dashboards'
    type: file
    options:
      path: /otel-lgtm/grafana/conf/provisioning/dashboards
```

### 7. Tempo crashing silently — WAL explosion

The default `tempo-config.yaml` in the image uses extremely aggressive ingester
settings designed for local demo use:

```yaml
ingester:
  trace_idle_period: 1s
  max_block_duration: 1s   # ← creates ~1 WAL block per second
  flush_check_period: 1s
```

Under real trace load from CF CLI apps (~1 trace/second each), Tempo creates
roughly one 500KB–900KB WAL block per second. After running for several hours,
this accumulates hundreds of blocks. On the next restart, WAL replay takes
15+ seconds and peak memory during burst ingestion kills the process. Since
`run-all.sh` has no service-restart logic, Tempo stays dead until the whole
app is restarted.

**Symptoms:** Grafana dashboard trace panels show
`dial tcp 127.0.0.1:3200: connect: connection refused` after a few minutes.

**Fix 1 — Sane Tempo ingester config** (prevents accumulation):

A custom `tempo-config.yaml` is baked into the image at build time:

```yaml
# cloud-foundry/lgtm/tempo-config.yaml
ingester:
  trace_idle_period: 30s
  max_block_duration: 2m   # ← one block per 2 minutes instead of per second
  flush_check_period: 30s
```

```dockerfile
# Dockerfile
COPY cloud-foundry/lgtm/tempo-config.yaml /otel-lgtm/tempo-config.yaml
```

**Fix 2 — Tempo watchdog** (recovers from crashes automatically):

A background shell loop in `entrypoint.sh` polls Tempo's `/ready` endpoint and
relaunches it if it goes down, without requiring a full CF app restart:

```sh
# entrypoint.sh
(
  sleep 120   # allow initial startup
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
```

---

## Key Image Facts (`grafana/otel-lgtm:latest`)

| Property | Value |
|---|---|
| Base OS | RHEL 9 |
| Package manager | **None** (no `apt`/`apk`/`yum`) |
| Startup script | `/otel-lgtm/run-all.sh` — **requires CWD `/otel-lgtm/`** |
| Grafana port | `3000` |
| Loki port | `3100` |
| Tempo HTTP API | `3200` |
| Tempo OTLP gRPC receiver | `4417` |
| Tempo OTLP HTTP receiver | `4418` |
| OTel Collector OTLP HTTP | `4318` |
| Built-in datasource UIDs | `prometheus`, `loki`, `tempo`, `pyroscope` |
| Provisioning path | `/otel-lgtm/grafana/conf/provisioning/` |
| Run as | `root` (uid=0) |

---

## Deployment Steps

### Prerequisites

- Docker Desktop (must be running with `linux/amd64` build support)
- Docker Hub account with push access to `<dockerhub-user>/crypto-broker-lgtm`
- CF CLI logged in to the target BTP subaccount
- `diego_docker` feature flag enabled in CF:
  ```bash
  cf enable-feature-flag diego_docker
  ```

### Build & Deploy

```bash
# 1. Copy and fill in vars.yaml
cp deployments/cloud-foundry/lgtm/vars.yaml.example \
   deployments/cloud-foundry/lgtm/vars.yaml
# Edit vars.yaml with your Docker Hub username, CF domain, and Grafana password.

# 2. Build the image (run from deployments/ so both cloud-foundry/ and docker/ are in context)
cd deployments
docker build --platform linux/amd64 \
  -f cloud-foundry/lgtm/Dockerfile \
  -t <dockerhub-user>/crypto-broker-lgtm:latest .

# 3. Push to Docker Hub
docker push <dockerhub-user>/crypto-broker-lgtm:latest

# 4. Deploy to CF
cd cloud-foundry/lgtm
cf push --vars-file vars.yaml

# Or use the Taskfile (from deployments/cloud-foundry/lgtm/):
task lgtm-build-push-deploy DOCKER_IMAGE=<dockerhub-user>/crypto-broker-lgtm:latest
```

### Configure CLI apps to send telemetry to CF LGTM

In both `deployments/cloud-foundry/go/manifest.yaml` and
`deployments/cloud-foundry/js/manifest.yaml`, set:

```yaml
env:
  OTEL_COLLECTOR_ENDPOINT: "https://crypto-broker-lgtm.<cf_domain>"
  # Fallback Option A (ngrok): uncomment and update when using local LGTM
  # OTEL_COLLECTOR_ENDPOINT: "https://<ngrok-id>.ngrok-free.app"
```

Then redeploy the CLI apps:

```bash
cf push --manifest deployments/cloud-foundry/go/manifest.yaml
cf push --manifest deployments/cloud-foundry/js/manifest.yaml
```

### Verify

```bash
# Check the app is running
cf app crypto-broker-lgtm

# Check Tempo is healthy
cf ssh crypto-broker-lgtm -c "curl -sf http://127.0.0.1:3200/ready && echo OK"

# Tail startup logs
cf logs crypto-broker-lgtm --recent
```

Open Grafana at `https://crypto-broker-lgtm.<cf_domain>` — credentials are
`admin` / the value set in `vars.yaml`. Navigate to
**Dashboards → Browse → CryptoBroker Overview**.

---

## Switching Between Options A and B

Both manifests keep both options as comments. Only one should be active at a time.

```yaml
# Option B — CF LGTM (always-on):
OTEL_COLLECTOR_ENDPOINT: "https://crypto-broker-lgtm.cfapps.eu12.hana.ondemand.com/"
# Option A — ngrok (local LGTM, dev fallback):
# OTEL_COLLECTOR_ENDPOINT: "https://<ngrok-id>.ngrok-free.app"
```

After changing the endpoint, redeploy the affected CLI app:

```bash
cf push --manifest deployments/cloud-foundry/<go|js>/manifest.yaml
```
