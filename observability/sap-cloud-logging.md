# Ingesting OpenTelemetry Data into SAP Cloud Logging from Cloud Foundry

Step-by-step guide based on the working setup for Go and JS CF applications.

---

## Overview

SAP Cloud Logging (CLS) exposes an OTLP **gRPC** endpoint that requires **mTLS** authentication. The key pitfalls to avoid:

- Do **not** use `otlphttp` — the CLS ingest-otlp endpoint speaks gRPC only.
- Do **not** use `https://` in the endpoint URL — gRPC format is `host:port`.
- Prefer extracting credentials live from `VCAP_SERVICES` at startup over hardcoding them in `vars.yaml` — the script approach handles rotation automatically. See [Fallback: vars.yaml](#fallback-varsyaml) if Python is unavailable.
- Do **not** rely on CF sidecar `env:` blocks — CF silently ignores them; inline all env vars in the `command`.

---

## Step 1 — Create and Bind the CLS Service Instance

The easiest way is via the **SAP BTP Cockpit**:

1. Navigate to your Cloud Foundry space → **Services** → **Service Marketplace**.
2. Find **SAP Cloud Logging** and click **Create**.
3. Select the plan (e.g. `standard`) and provide an instance name.
4. Under **Parameters (JSON)**, paste the configuration and click **Create**:
   ```json
   {
     "ingest_otlp": { "enabled": true },
     "retention_period": 7
   }
   ```
5. Once the instance is created, go to the instance → **Bindings** → **Bind Application**, select your app, and confirm.

> `retention_period` is in **days** (range 1–90, default 7).  
> `ingest_otlp.enabled: true` is mandatory — the OTLP endpoint is disabled by default.

Alternatively, use the CF CLI:

```bash
# Create a standard-plan instance
cf create-service cloud-logging standard crypto-broker-sapcl \
  -c '{"ingest_otlp": {"enabled": true}, "retention_period": 7}'

# Bind it to your app
cf bind-service <your-app> crypto-broker-sapcl
```

Either way, verify the credentials are available afterwards:

```bash
cf env <your-app> | grep -A5 "cloud-logging"
```

The binding populates `VCAP_SERVICES` with:
- `credentials.ingest-otlp-endpoint` — gRPC host (no port, no protocol)
- `credentials.ingest-otlp-cert` — PEM client certificate
- `credentials.ingest-otlp-key` — PEM private key

The certificate has a finite validity period. Check the expiry:
```bash
cf env <your-app> | python3 -c "
import sys, json
v = json.load(sys.stdin) if False else json.loads(input())
" 
# Or: cf ssh <app> -c "echo \$VCAP_SERVICES | python3 -c \
#   \"import json,sys,subprocess; d=json.loads(sys.stdin.read()); \
#   c=d['cloud-logging'][0]['credentials']['ingest-otlp-cert']; \
#   open('/tmp/c.pem','w').write(c)\" && openssl x509 -in /tmp/c.pem -noout -enddate"
```

---

## Step 2 — Add the Credential Extraction Script

Create `extract-cls-creds.py` alongside `otelcol` in your CF deployment directory:

```python
import json, os

vcap = json.loads(os.environ["VCAP_SERVICES"])
creds = vcap["cloud-logging"][0]["credentials"]

open("/tmp/cls-otlp.crt", "w").write(creds["ingest-otlp-cert"])
open("/tmp/cls-otlp.key", "w").write(creds["ingest-otlp-key"])

print("CLS mTLS credentials written to /tmp/cls-otlp.crt and /tmp/cls-otlp.key")
```

This writes the cert and key to `/tmp` at startup. No manual rotation is needed — the next app restart picks up fresh credentials automatically when the binding is renewed.

---

## Fallback: vars.yaml

If Python is not available in the CF container, you can extract the credentials manually from `cf env` and supply them via a `vars.yaml` file. This approach requires manual rotation whenever the certificate is renewed.

**1. Extract credentials from the current binding:**

```bash
# Print the cert and key to copy into vars.yaml
cf env <your-app> | python3 -c "
import sys, json
vcap = json.loads([l for l in sys.stdin if 'VCAP_SERVICES' in l][0].split(':', 1)[1])
creds = vcap['cloud-logging'][0]['credentials']
print('CLS_OTLP_CERT:', creds['ingest-otlp-cert'][:60], '...')
print('CLS_OTLP_KEY:', creds['ingest-otlp-key'][:60], '...')
"
```

**2. Create `vars.yaml` next to `manifest.yaml`:**

```yaml
CLS_OTLP_CERT: |
  -----BEGIN CERTIFICATE-----
  <paste full PEM here>
  -----END CERTIFICATE-----
CLS_OTLP_KEY: |
  -----BEGIN EC PRIVATE KEY-----
  <paste full PEM here>
  -----END EC PRIVATE KEY-----
```

**3. Change the sidecar command in `manifest.yaml` to write the files from env vars:**

```yaml
    env:
      CLS_OTLP_CERT: "((CLS_OTLP_CERT))"
      CLS_OTLP_KEY:  "((CLS_OTLP_KEY))"

    sidecars:
      - name: otel-collector
        process_types: [web]
        memory: 64M
        command: >
          printf '%s' "$CLS_OTLP_CERT" > /tmp/cls-otlp.crt &&
          printf '%s' "$CLS_OTLP_KEY"  > /tmp/cls-otlp.key &&
          ./otelcol --config=otel-config.yaml
```

**4. Deploy passing the vars file:**

```bash
cf push --vars-file vars.yaml
```

> **Warning:** `vars.yaml` contains private key material — never commit it to version control. Add it to `.gitignore`. When the certificate rotates, you must update the file and redeploy manually.

---

## Step 3 — Configure the OTel Collector

Create `otel-config.yaml` in the same deployment directory:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 40
    spike_limit_mib: 10
  batch:

exporters:
  otlp_grpc:                                    # gRPC exporter — required for CLS
    endpoint: ${env:OTEL_COLLECTOR_ENDPOINT}    # host:port format, no https://
    tls:
      insecure: false
      cert_file: /tmp/cls-otlp.crt             # written by extract-cls-creds.py
      key_file:  /tmp/cls-otlp.key
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 120s

service:
  telemetry:
    logs:
      level: warn
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_grpc]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_grpc]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp_grpc]
```

> **Note:** Use `otlp_grpc` as the exporter key (the alias `otlp` still works but prints a deprecation warning in OTel Collector ≥ 0.145).

---

## Step 4 — Configure the CF Manifest

In `manifest.yaml`, set the CLS endpoint as an env var and wire the sidecar. Two options for supplying the mTLS credentials:

### Option A — Python script (recommended)

The sidecar command runs `extract-cls-creds.py` (from Step 2) before starting the collector. Credentials are always read live from `VCAP_SERVICES`, so no manual rotation is needed.

```yaml
applications:
  - name: my-app
    path: my-deployment          # directory containing otelcol, otel-config.yaml,
                                  # extract-cls-creds.py, and your application binary
    env:
      # gRPC format: host:port — no https:// prefix
      OTEL_COLLECTOR_ENDPOINT: "ingest-otlp-sf-<instance-guid>.cls-<region>.cloud.logs.services.sap.hana.ondemand.com:443"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://localhost:4317"   # app → local sidecar

    sidecars:
      - name: otel-collector
        process_types: [web]
        memory: 64M
        # Run credential extraction first, then start the collector.
        # CF sidecar env: blocks are silently ignored — all env vars must be
        # inlined in the command string.
        command: 'python3 extract-cls-creds.py && ./otelcol --config=otel-config.yaml'
```

### Option B — vars.yaml (fallback)

Use this if Python is not available in the container. Credentials are passed as CF variable substitutions and written to `/tmp` via `printf`. See the [Fallback: vars.yaml](#fallback-varsyaml) section for how to populate `vars.yaml`.

```yaml
applications:
  - name: my-app
    path: my-deployment
    env:
      OTEL_COLLECTOR_ENDPOINT: "ingest-otlp-sf-<instance-guid>.cls-<region>.cloud.logs.services.sap.hana.ondemand.com:443"
      OTEL_EXPORTER_OTLP_ENDPOINT: "http://localhost:4317"
      CLS_OTLP_CERT: "((CLS_OTLP_CERT))"
      CLS_OTLP_KEY:  "((CLS_OTLP_KEY))"

    sidecars:
      - name: otel-collector
        process_types: [web]
        memory: 64M
        command: >
          printf '%s' "$CLS_OTLP_CERT" > /tmp/cls-otlp.crt &&
          printf '%s' "$CLS_OTLP_KEY"  > /tmp/cls-otlp.key &&
          ./otelcol --config=otel-config.yaml
```

Deploy with:

```bash
cf push --vars-file vars.yaml
```

> **Warning:** `vars.yaml` contains private key material — never commit it to version control. Credentials must be updated manually when the certificate rotates.

---

> **Critical (both options):** The `OTEL_COLLECTOR_ENDPOINT` env var set at the app level is inherited by the sidecar, because CF ignores sidecar-level `env:` blocks. Set it once on the app.

---

## Step 5 — Deploy and Verify

```bash
cd deployments/cloud-foundry/<your-app>
cf push

# Verify the credential extraction ran successfully
cf logs <your-app> --recent | grep "OTEL-COLLECTOR" | grep "credentials"
# Expected output:
# OUT CLS mTLS credentials written to /tmp/cls-otlp.crt and /tmp/cls-otlp.key

# Verify the files exist inside the container
cf ssh <your-app> -c "ls -la /tmp/cls-otlp.*"
# Expected:
# -rw-r--r-- 1 vcap vcap 1984 May 12 16:54 /tmp/cls-otlp.crt
# -rw-r--r-- 1 vcap vcap 2484 May 12 16:54 /tmp/cls-otlp.key

# Check for export errors (should be none)
cf logs <your-app> --recent | grep "OTEL-COLLECTOR" | grep -i "error\|Error"
```

---

## Credential Rotation

The mTLS certificate in the CLS binding expires periodically (check the `Not After` field via `openssl x509`). To rotate:

```bash
cf unbind-service <your-app> crypto-broker-sapcl
cf bind-service   <your-app> crypto-broker-sapcl
cf restart        <your-app>
```

The `extract-cls-creds.py` script always reads from `VCAP_SERVICES` at startup, so no file changes are needed.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `IndentationError: unexpected indent` in sidecar logs | Inline Python in sidecar `command` — CF wraps it in `bash -c '...'` causing quote conflicts | Use a `.py` script file instead of inline `python3 -c "..."` |
| OTel collector starts but no data arrives | `env:` block on sidecar ignored by CF | Inline `OTEL_COLLECTOR_ENDPOINT` in the sidecar `command`, or set it on the parent app env |
| `HTTP Status Code 404` export error | Using `otlphttp` exporter against a gRPC-only endpoint | Switch to `otlp_grpc` exporter and remove `https://` from endpoint |
| `connection refused` or TLS handshake error | Missing `cert_file`/`key_file` in exporter TLS config | Add both fields pointing to `/tmp/cls-otlp.crt` and `/tmp/cls-otlp.key` |
| Sidecar cert/key files empty or missing | `extract-cls-creds.py` failed silently | Check `cf logs --recent` for Python errors; verify `VCAP_SERVICES` contains `cloud-logging` key |

---

## References

- [What Is SAP Cloud Logging?](https://help.sap.com/docs/cloud-logging/cloud-logging/what-is-sap-cloud-logging?locale=en-US)
- [SAP Cloud Logging — Configuration Parameters](https://help.sap.com/docs/cloud-logging/cloud-logging/configuration-parameters?locale=en-US) — `retention_period`, `ingest_otlp.enabled`, service plans
- [SAP Cloud Logging — Ingest via OpenTelemetry API Endpoint](https://help.sap.com/docs/cloud-logging/cloud-logging/ingest-via-opentelemetry-api-endpoint?locale=en-US)
- [SAP Cloud Logging — Service Plans](https://help.sap.com/docs/cloud-logging/cloud-logging/service-plans?locale=en-US)
- [OpenTelemetry Collector — OTLP gRPC Exporter](https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/otlpexporter/README.md)
- [Cloud Foundry — App Manifest — Sidecars](https://docs.cloudfoundry.org/devguide/sidecars.html)
