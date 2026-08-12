# SAP BTP Cloud Foundry: Dynatrace OneAgent Integration Guide

## Multi-Buildpack Node.js Application with Go Sidecars

This guide provides a streamlined, step-by-step walkthrough for configuring
and automatically injecting the Dynatrace OneAgent into a Cloud Foundry
application on SAP BTP using multiple buildpacks (`nodejs_buildpack` and
`binary_buildpack`), covering both OneAgent system-level monitoring and OTLP
telemetry ingestion (traces, metrics, and logs).

---

## Architecture Overview

* **Primary Application:** Node.js CLI / Web service
  (`crypto-broker-js-cli`).
* **Sidecars:** Go binaries for server/client profiles.
* **Telemetry Stack:** OpenTelemetry (OTLP) exporting logs, metrics, and
  traces alongside system-level Dynatrace OneAgent monitoring.
* **Key Platform Behavior:** The SAP Node.js buildpack executes the Dynatrace
  decorator hook during application staging if it acts as the primary
  buildpack supplier.

---

## Step 1: Create the Dynatrace Managed Service Instance

Create the Dynatrace service instance from the SAP BTP Service Marketplace
(or via CLI) **without** passing any custom parameters during creation. The
managed service broker automatically injects core endpoint credentials.

### Via CF CLI

```bash
cf create-service dynatrace <service-plan> dynatrace-service
```

*(Or create the service instance directly through the SAP BTP Cockpit UI
under **Instances and Subscriptions**).*

---

## Step 2: Bind the Service Instance with Ingestion Scopes

When creating the service binding, pass the JSON payload defining the
required API scopes (`InstallerDownload` for OneAgent binary download and
OpenTelemetry ingestion scopes for OTLP data).

> **Important:** Do not include `apiurl`, `apitoken`, or `environmentid` in
> the binding payload. The SAP BTP managed broker handles these internally
> and will reject custom parameters.

The payload contains two distinct token structures:

* **`rest_apitoken`** — creates the token the **OneAgent installer** uses at
  staging time to download the agent binary. Requires at minimum
  `InstallerDownload`.
* **`tokens` → `otlp_token`** — creates a separately named token that the
  **OTLP exporters** (Node.js and Go processes) use at runtime to ingest
  telemetry. Requires `metrics.ingest`, `openTelemetryTrace.ingest`, and
  `logs.ingest`.

### Service Binding JSON Payload (`binding-params.json`)

```json
{
  "rest_apitoken": {
    "scopes": [
      "InstallerDownload",
      "metrics.ingest",
      "openTelemetryTrace.ingest",
      "logs.ingest"
    ]
  },
  "token_expiresin": "1y",
  "tokens": [
    {
      "name": "otlp_token",
      "scopes": [
        "InstallerDownload",
        "metrics.ingest",
        "openTelemetryTrace.ingest",
        "logs.ingest"
      ]
    }
  ]
}
```

### Apply Binding via CF CLI

```bash
cf bind-service crypto-broker-js-cli dynatrace-service -c binding-params.json
```

*(Or perform the binding in **SAP BTP Cockpit** > **Applications** >
**`crypto-broker-js-cli`** > **Service Bindings**, pasting the JSON above
into the parameter box).*

---

## Step 3: Configure `manifest.yml` Buildpack Ordering

Buildpack order is critical for multi-buildpack applications. Place
`binary_buildpack` **first** and `nodejs_buildpack` **last**. This ensures
`nodejs_buildpack` acts as the primary supply-chain provider and triggers the
Dynatrace OneAgent hook.

> **Important — Sidecar Environment Variables:** Cloud Foundry silently
> ignores `env:` blocks defined at the sidecar level. All environment
> variables for sidecars **must** be set inline in the `command:` string.
> Only the top-level application `env:` block is applied to the main process.

### Complete `manifest.yml`

```yaml
applications:
  - name: crypto-broker-js-cli
    instances: 1
    memory: 1G
    disk_quota: 1G
    path: js-deployment
    buildpacks:
      - binary_buildpack
      - nodejs_buildpack
    health-check-type: process
    process_types: [web]
    env:
      HUSKY: 0
      OTEL_TRACES_SAMPLER: "always_on"
      OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE: "delta"
      OTEL_METRICS_INTERVAL: "10s"
    command: 'OTEL_SERVICE_NAME=test-app-js-hash OTEL_LOGS_EXPORTER="otlpproto"
      OTEL_TRACES_EXPORTER="otlpproto" OTEL_METRICS_EXPORTER="otlpproto"
      node dist/cli.js --loop 1000 hash-data --profile=KAT_SHA3_512
      "Welcome CryptoBroker"'

    sidecars:
      - name: crypto-broker-server
        health-check-type: process
        process_types: [web]
        # CF silently ignores sidecar-level env blocks — all env vars must
        # be set inline
        command: 'GODEBUG=fips140=off OTEL_SERVICE_NAME=test-crypto-broker-server
          OTEL_LOGS_EXPORTER="otlphttp" OTEL_TRACES_EXPORTER="otlphttp"
          OTEL_METRICS_EXPORTER="otlphttp" CRYPTO_BROKER_PROFILES_DIR=$PWD
          ./cryptobroker-server'

      - name: crypto-broker-client-profile-default
        health-check-type: process
        process_types: [web]
        # CF silently ignores sidecar-level env blocks — all env vars must
        # be set inline
        command: 'OTEL_SERVICE_NAME=test-app-js-default-profile
          OTEL_LOGS_EXPORTER="otlpproto" OTEL_TRACES_EXPORTER="otlpproto"
          OTEL_METRICS_EXPORTER="otlpproto" node dist/cli.js --loop 1000 hash-data
          --profile=Default "Welcome CryptoBroker"'
```

**OTLP exporter values explained:**

* Node.js processes use `"otlpproto"` (protobuf over HTTP). Using
  `"otlphttp"` (JSON) causes Dynatrace to return HTTP 415 on log ingestion.
* The Go server sidecar uses `"otlphttp"` — the Go OTel HTTP exporter sends
  protobuf by default regardless of this value.

---

## Step 4: Deploy and Restage

Choose the appropriate command based on what changed:

* **`cf push`** — use when the application code, `manifest.yml`, or buildpack
  configuration has changed. Uploads a new artifact and re-stages from
  scratch.
* **`cf restage`** — use when only a service binding or environment variable
  has changed and no new code needs to be deployed. Re-stages the existing
  droplet without re-uploading.

```bash
# Full deployment (code or manifest changed)
cf push
```

or

```bash
# Re-stage only (binding or env changed, no new code)
cf restage crypto-broker-js-cli
```

---

## Step 5: Verification

### 1. Staging Log Confirmation

Monitor the staging output to verify that the Dynatrace OneAgent installer
executes successfully:

```text
Dynatrace service credentials found. Setting up Dynatrace OneAgent.
-----> Starting Dynatrace OneAgent installer
Dynatrace OneAgent installed.
-----> Setting up Dynatrace OneAgent injection...
Dynatrace OneAgent injection is set up.
Exit status 0
```

### 2. Dynatrace Console Verification

* **Host Monitoring:** Navigate to **Hosts** in the Dynatrace UI. The
  container instance **`crypto-broker-js-cli`** will appear as a monitored
  entity.
* **Metrics Ingestion:** Navigate to **Metrics / Data Explorer** and query
  `builtin:host.*` (e.g., `builtin:host.cpu.usage`, `builtin:host.mem.usage`)
  to observe real-time system metrics.
* **OTLP Telemetry:** Custom metrics, traces, and logs exported from the
  Node.js process and Go sidecar binaries via OTLP will automatically
  correlate with the host entity.
