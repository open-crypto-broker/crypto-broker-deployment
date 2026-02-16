# Dynatrace

To successfully go through this guide you will need:
- [API token](https://docs.dynatrace.com/docs/dynatrace-api/basics/dynatrace-api-authentication)
- [Base URL](https://docs.dynatrace.com/docs/shortlink/otel-getstarted-otlpexport#base-url)

## Traces

### Ingestion methods

There are 3 methods to dispatch OTEL traces to dynatrace
- [Dynatrace OTLP API](https://docs.dynatrace.com/docs/ingest-from/opentelemetry/otlp-api/ingest-traces) (HTTPs)
- [Dynatrace Collector](https://docs.dynatrace.com/docs/ingest-from/opentelemetry/collector) 
- OTEL Collector

#### Dynatrace OTLP API

This method assumes that application will directly send traces through HTTP(s) to dynatrace utilizing dynatrace's API.

To make it happen you need to have following environment variables set
- `OTEL_TRACES_EXPORTER: "otlphttp"`
- `OTEL_EXPORTER_OTLP_ENDPOINT: "https://<YOUR-TENANT-HERE>.live.dynatrace.com/api/v2/otlp"`
- `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION: "Api-Token <YOUR-TOKEN-HERE>"`
- `OTEL_TRACES_SAMPLER: "always_on"`

Next, you need to run sever 
```
task run
```

And from CLI invoke any command
```
task test-sign
```

#### Dynatrace collector

This method uses external program "dynatrace collector" that is proxy between client and dynatrace. In our case we send data to dynatrace collector using gRPC and dynatrace collector will send them to dynatrace using HTTPs

*Please note, that `dynatrace collector` & `otel collector` are meant to listen to the same port, therefore before turning one, turn off another.* 

1. Create `dynatrace-collector-config.yaml` file
2. Fill it with following content
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  otlphttp:
    endpoint: https://<YOUR-TENANT-HERE>.live.dynatrace.com/api/v2/otlp
    headers:
      Authorization: "Api-Token <YOUR-TOKEN-HERE>"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: []
      exporters: [otlphttp]
    metrics:
      receivers: [otlp]
      processors: []
      exporters: [otlphttp]
    logs:
      receivers: [otlp]
      processors: []
      exporters: [otlphttp]
```

3. Run collector with docker `docker run -d -p 4317:4317 -v $(pwd)/dynatrace-collector-config.yaml:/etc/otelcol/otel-collector-config.yaml ghcr.io/dynatrace/dynatrace-otel-collector/dynatrace-otel-collector:0.42.0 --config=/etc/otelcol/otel-collector-config.yaml` from directory that contains dynatrace-collector-config.yaml file.

*if you are missing image, please pull it with `docker pull ghcr.io/dynatrace/dynatrace-otel-collector/dynatrace-otel-collector:0.42.0`.*

4. Set environment variables to following in CLI and server
- `OTEL_TRACES_EXPORTER: "otlpgrpc"`
- `OTEL_EXPORTER_OTLP_ENDPOINT: "localhost:4317"`
- `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION: "Api-Token <YOUR-TOKEN-HERE>"`
- `OTEL_TRACES_SAMPLER: "always_on"`

5. Run server `task run`
6. From CLI run any command `task test-hash`

#### OTEL Collector

This method uses external program [OTEL collector](https://github.com/open-telemetry/opentelemetry-collector) that is proxy between client and dynatrace. In our case we send data to `OTEL collector` using gRPC and `OTEL collector` will send them to dynatrace using HTTPs.

*Please note, that `dynatrace collector` & `otel collector` are meant to listen to the same port, therefore before turning one, turn off another.* 

1. Create file `otel-collector-config.yaml`
2. Fill it with following content:
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317  # Receive gRPC OTLP from your server

exporters:
  otlphttp:
    endpoint: https://<YOUR-TENANT>.live.dynatrace.com/api/v2/otlp
    headers:
      Authorization: "Api-Token <YOUR-API-TOKEN>"

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [otlphttp]
```
3. Run `OTEL Collector` with `docker run -d --name otel-collector \
  -p 4317:4317 \
  -v $(pwd)/otel-collector-config.yaml:/etc/otel-collector-config.yaml \
  otel/opentelemetry-collector-contrib:latest \
  --config /etc/otel-collector-config.yaml`

*if you are missing image, please pull it with `docker pull otel/opentelemetry-collector-contrib:latest`.*

4. Set environment variables to following in CLI and server
- `OTEL_TRACES_EXPORTER: "otlpgrpc"`
- `OTEL_EXPORTER_OTLP_ENDPOINT: "localhost:4317"`
- `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION: "Api-Token <YOUR-TOKEN-HERE>"`
- `OTEL_TRACES_SAMPLER: "always_on"`

5. Run server `task run`
6. From CLI run any command `task test-benchmark`

## Logs

### Ingestion methods

This guide utilizes 2 method to dispatch OTEL logs to dynatrace:
- Dynatrace OTLP API
- Dynatrace collector

#### Dynatrace OTLP API

This method assumes that application will directly send logs through HTTP(s) to dynatrace utilizing dynatrace's API.

To make it happen you need to have following environment variables set:
- `OTEL_LOGS_EXPORTER: "otlphttp"`
- `OTEL_EXPORTER_OTLP_ENDPOINT: "https://<YOUR-TENANT-HERE>.live.dynatrace.com/api/v2/otlp"`
- `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION: "Api-Token <YOUR-API-TOKEN-HERE>>"`

Next, run server with `task run`.

#### Dynatrace collector

This method uses external program "dynatrace collector" that is proxy between client and dynatrace. In our case we send logs to dynatrace collector using gRPC and dynatrace collector will send them to dynatrace using HTTPs

1. Create `dynatrace-collector-config.yaml` file
2. Fill it with following content
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  otlphttp:
    endpoint: https://<YOUR-TENANT-HERE>.live.dynatrace.com/api/v2/otlp
    headers:
      Authorization: "Api-Token <YOUR-TOKEN-HERE>"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: []
      exporters: [otlphttp]
    metrics:
      receivers: [otlp]
      processors: []
      exporters: [otlphttp]
    logs:
      receivers: [otlp]
      processors: []
      exporters: [otlphttp]
```

3. Run collector with docker `docker run -d -p 4317:4317 -v $(pwd)/dynatrace-collector-config.yaml:/etc/otelcol/otel-collector-config.yaml ghcr.io/dynatrace/dynatrace-otel-collector/dynatrace-otel-collector:0.42.0 --config=/etc/otelcol/otel-collector-config.yaml` from directory that contains dynatrace-collector-config.yaml file.

*if you are missing image, please pull it with `docker pull ghcr.io/dynatrace/dynatrace-otel-collector/dynatrace-otel-collector:0.42.0`.*

4. Set environment variables to following in server
- `OTEL_LOGS_EXPORTER: "otlpgrpc"`
- `OTEL_EXPORTER_OTLP_ENDPOINT: "localhost:4317"`

5. Run server `task run`

### Usefull links

- https://docs.dynatrace.com/docs/analyze-explore-automate/logs/lma-log-ingestion
- https://docs.dynatrace.com/docs/analyze-explore-automate/logs/lma-log-ingestion/lma-log-ingestion-via-api
- https://docs.dynatrace.com/docs/dynatrace-api/environment-api/log-monitoring-v2/post-ingest-logs
- https://docs.dynatrace.com/docs/ingest-from/opentelemetry/otlp-api/ingest-logs
- https://docs.dynatrace.com/docs/ingest-from/opentelemetry/collector/use-cases
- https://docs.dynatrace.com/docs/ingest-from/opentelemetry/otlp-api
- [How to corelate Logs with traces](https://docs.dynatrace.com/docs/analyze-explore-automate/logs/lma-log-enrichment#span-examples--go-with-the-oneagent-sdk)

## Metrics