# Guide for Trace Context Propagation for Dynatrace

## Purpose

This guide walks through diagnosing and fixing the **"No related services"** issue in Dynatrace, where a service is correctly detected and monitored on its own, but calls between it and other services aren't linked together in the topology / distributed trace view.

It applies to services instrumented with **OpenTelemetry (OTLP)** — rather than Dynatrace OneAgent — communicating over **gRPC**, and covers both **Node.js** and **Go** clients calling a **Go gRPC server**. The same underlying principles (propagator configuration, header injection, server-side extraction, export pipeline correctness) apply to other language SDKs and transports (HTTP, other RPC frameworks) with minor adaptations.

Use this guide as a step-by-step checklist when:

- A service appears in Dynatrace's Service list, but "Related services" shows empty
- Traces, logs, or metrics for a service seem to be missing or incomplete
- You're wiring up a new client language/service to an existing, working backend and need it to show up correctly in the topology

---

## Step 1: Confirm the symptom and where it points

If a service shows up in Dynatrace but "Related services" is empty, the problem is almost always in **distributed trace context propagation** — the caller and callee aren't sharing a trace ID — rather than a monitoring/agent installation issue. This is especially relevant if you're using OTLP-only ingestion rather than OneAgent, since there's no automatic infrastructure-level detection to fall back on.

---

## Step 2: Enable client-side trace context propagation (language-specific)

### Node.js client

```js
registerInstrumentations({
  tracerProvider: tracingProvider,
  instrumentations: [ new GrpcInstrumentation() ],
});
```

### Go client

```go
otel.SetTextMapPropagator(
    propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ),
)
```

Then either use `grpc.WithStatsHandler(otelgrpc.NewClientHandler())` at dial time, or manually inject trace context via a `TextMapCarrier` wrapping outgoing gRPC metadata:

```go
// InjectGRPCTraceContext adds the active trace context to outgoing gRPC metadata.
func InjectGRPCTraceContext(ctx context.Context) context.Context {
    md, _ := metadata.FromOutgoingContext(ctx)
    md = md.Copy()

    otelapi.GetTextMapPropagator().Inject(ctx, grpcMetadataCarrier(md))
    return metadata.NewOutgoingContext(ctx, md)
}

type grpcMetadataCarrier metadata.MD

func (c grpcMetadataCarrier) Get(key string) string {
    values := metadata.MD(c).Get(key)
    if len(values) == 0 {
        return ""
    }
    return values[0]
}

func (c grpcMetadataCarrier) Set(key, value string) {
    metadata.MD(c).Set(key, value)
}

func (c grpcMetadataCarrier) Keys() []string {
    keys := make([]string, 0, len(c))
    for key := range c {
        keys = append(keys, key)
    }
    return keys
}

var _ propagation.TextMapCarrier = grpcMetadataCarrier{}
```

Call this after starting a span with `trace.WithSpanKind(trace.SpanKindClient)` and before making the RPC:

```go
ctx, span := tracer.Start(ctx, "Some.Trace",
    trace.WithSpanKind(trace.SpanKindClient),
    trace.WithAttributes(...),
)
ctx = otel.InjectGRPCTraceContext(ctx)
```

In both languages, the underlying principle is the same: **the client must have a configured propagator and must actively write trace context into outgoing request metadata/headers.** Without this, any manually-embedded trace IDs elsewhere (e.g., stuffed into a payload field) are invisible to Dynatrace's topology detection, which relies on standard header-based propagation.

---

## Step 3 (Node.js only): Register the ESM loader hook if using native ES modules

```bash
NODE_OPTIONS="--experimental-loader=@opentelemetry/instrumentation/hook.mjs"
```

Required because `GrpcInstrumentation`'s monkey-patching needs Node's module loader intercepted; without it, instrumentation appears registered but never actually patches the gRPC library. There's no equivalent step needed for Go — no monkey-patching is involved, since the propagator/injection code runs directly as part of your own call path.

**How to verify Steps 2–3 worked (either language):** log incoming gRPC metadata server-side and confirm a `traceparent` key is present with a valid W3C-format value, e.g.:

```text
key="traceparent" value=[00-<32 hex trace id>-<16 hex span id>-01]
```

Example Go snippet to add temporarily in the server handler for this check:

```go
md, ok := metadata.FromIncomingContext(ctx)
fmt.Printf("DEBUG metadata ok=%v count=%d\n", ok, len(md))
for k, v := range md {
    fmt.Printf("DEBUG metadata key=%q value=%v\n", k, v)
}
```

---

## Step 4: Ensure the server-side OTel gRPC integration is in place

```go
server := grpc.NewServer(
    grpc.ChainUnaryInterceptor(...),
    grpc.StatsHandler(otelgrpc.NewServerHandler()),
)
```

This automatically extracts `traceparent` from incoming gRPC metadata — regardless of which language/client sent it, since it's a standard W3C header — and creates a properly-linked server span. This is language-agnostic: one server-side fix covers all clients (Go, Node.js, or otherwise), as long as each client correctly performs Step 2.

---

## Step 5 (Node.js client only): Fix the OTLP export pipeline (traces not reaching Dynatrace at all)

Correct propagation alone isn't enough — spans still need to be exported successfully. This was specific to the Node.js client in this case; the Go client/server did not require these adjustments.

- Use `otlpproto` (protobuf), not `otlphttp` (JSON), if your ingestion endpoint requires it. Confirm the endpoint's expected format directly with `curl`:

```bash
curl -v -X POST "https://<your-otlp-endpoint>/v1/traces" \
  -H "Content-Type: application/x-protobuf" \
  -H "Authorization: Api-Token <your-token>" \
  --data-binary ""
```

A `200 OK` response (check the `< HTTP/1.1 200 OK` line in the verbose output) confirms the endpoint accepts this content type and path; a `415 Unsupported Media Type` or `404 Not Found` tells you the content-type or path is wrong before you spend time debugging the SDK.

- Append the correct OTLP path to the exporter URL: `/v1/traces` for traces, `/v1/logs` for logs.
- Explicitly set the `Content-Type: application/x-protobuf` header on the exporter's collector options — don't rely on the exporter package to set it automatically when custom headers (like `Authorization`) are also being set.

---

## Step 6: Confirm end-to-end at the raw data level

Don't rely solely on the "Related services" UI panel, which can lag or apply its own filtering/timeframe logic independent of raw data availability. Check raw ingested trace data directly:

- **Dynatrace Managed**: Distributed Traces → Ingested traces → search by trace ID

> Note: this guide was validated on **Dynatrace Managed**. If you're on **Dynatrace SaaS/Grail**, the equivalent check is via Notebooks → DQL query (e.g. `fetch spans | filter service.name == "..."`), but this hasn't been verified as part of this guide — confirm the exact navigation/syntax against current Dynatrace SaaS documentation.

Confirm the client and server spans share the same trace ID, with the server span correctly parented under the client span.

---

## Step 7: Ensure every service instance actually has exporters configured

In multi-process/sidecar deployments, double check **every individual process** — not just the ones you're actively debugging — has its exporter type, endpoint, and auth explicitly set (`OTEL_TRACES_EXPORTER`, `OTEL_LOGS_EXPORTER`, `OTEL_METRICS_EXPORTER`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS_AUTHORIZATION`, etc.). A missing exporter env var silently results in no data being exported at all for that instance, which looks identical to a propagation failure from the outside.
