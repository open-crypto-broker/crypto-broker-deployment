# Stage 1: compile a tiny static Go reverse proxy (no external dependencies).
# Routes CF's single $PORT: /v1/* → OTLP HTTP (4318), /* → Grafana (3000).
FROM --platform=linux/amd64 golang:1.24-alpine AS proxy-builder
WORKDIR /src
COPY cloud-foundry/lgtm/proxy/main.go .
# CGO_ENABLED=0 produces a fully static binary that runs on any Linux
RUN go mod init cfproxy && CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /cf-proxy .

# Stage 2: extend the official LGTM all-in-one image with the proxy binary.
# Build context must be the deployments/ directory so both cloud-foundry/lgtm/
# and docker/lgtm/ paths are accessible.
#
# Build:   docker build -f cloud-foundry/lgtm/Dockerfile -t <image> .
#          (run from the deployments/ directory)
FROM --platform=linux/amd64 grafana/otel-lgtm:latest

# Drop in the static proxy binary from stage 1
COPY --from=proxy-builder /cf-proxy /cf-proxy

# Override Tempo's aggressive ingester settings (1s block duration) with sane
# values (2m blocks, 30s flush period) to prevent WAL explosion and OOM kills.
COPY cloud-foundry/lgtm/tempo-config.yaml /otel-lgtm/tempo-config.yaml

# Override Loki config to enable the compactor with retention (default has no
# retention → chunks accumulate indefinitely → OOM crash after several days).
COPY cloud-foundry/lgtm/loki-config.yaml /otel-lgtm/loki-config.yaml

# The image already has datasources provisioned at /otel-lgtm/grafana/conf/provisioning/datasources/
# with UIDs: prometheus, loki, tempo — do NOT add our own (causes duplicate name conflict).
# Copy the shared dashboard JSON, then remap its datasource UIDs to match the image's built-in ones.
COPY docker/lgtm/observability/grafana/provisioning/dashboards/cryptobroker-overview.json \
     /otel-lgtm/grafana/conf/provisioning/dashboards/cryptobroker-overview.json
RUN sed -i \
        -e 's/prometheus-lgtm/prometheus/g' \
        -e 's/loki-lgtm/loki/g' \
        -e 's/tempo-lgtm/tempo/g' \
    /otel-lgtm/grafana/conf/provisioning/dashboards/cryptobroker-overview.json

# Add the dashboard loader config pointing at the provisioning dashboards directory
COPY cloud-foundry/lgtm/grafana/provisioning/dashboards/dashboards.yaml \
     /otel-lgtm/grafana/conf/provisioning/dashboards/cryptobroker-dashboards.yaml

# CF-specific entrypoint: starts the Go proxy then the original LGTM stack
COPY cloud-foundry/lgtm/entrypoint.sh /cf-entrypoint.sh
RUN chmod +x /cf-entrypoint.sh

CMD ["/cf-entrypoint.sh"]
