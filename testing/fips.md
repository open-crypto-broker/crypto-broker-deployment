# FIPS Deployment Testing

This document describes how to test the Crypto Broker Server with FIPS 140-3
strict mode on Cloud Foundry, Kubernetes, and Docker Compose. For details about
the Go FIPS module and the server configuration, see the
[server FIPS documentation](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/docs/fips.md).

## Configuration

FIPS mode has a build-time and a runtime setting:

| Task variable | Purpose | Default |
| --- | --- | --- |
| `FIPS_MODE_MODULE_VERSION` | Selects the build module | `off` |
| `FIPS_GODEBUG_VALUE` | Sets `GODEBUG` when the server starts | `fips140=off` |

The strict-mode tests use the certified module and runtime enforcement:

```text
FIPS_MODE_MODULE_VERSION=v1.0.0
FIPS_GODEBUG_VALUE=fips140=only
```

The deployment profiles define a SHA-2 Subject Key Identifier hash explicitly.
This is required because the server otherwise uses SHA-1 for compatibility, and
Go rejects SHA-1 in strict mode.

## Test criteria

A platform test is successful when:

1. The deployed server starts and remains ready.
2. The server logs report that FIPS mode is enabled.
3. The logs report module version `v1.0.0` and `enforced=true`.
4. The client completes a request with a profile that strict mode permits.
5. The server does not restart while the request is processed.

The expected server log messages are:

```text
FIPS mode is enabled
FIPS mode version
FIPS mode enforced
```

## Cloud Foundry

Log in to a non-production Cloud Foundry space before running the deployment.
The task builds the Linux server binary with the selected FIPS module and then
starts it as a sidecar with strict mode enabled.

```shell
task cf-deploy \
  CLIENT=go \
  BRANCH=main \
  FIPS_MODE_MODULE_VERSION=v1.0.0 \
  FIPS_GODEBUG_VALUE=fips140=only
```

Check the application and the server logs:

```shell
cf app crypto-broker-go-cli
cf_logs="$(cf logs crypto-broker-go-cli --recent)"
grep -F 'FIPS mode is enabled' <<<"$cf_logs"
grep -F 'FIPS mode version' <<<"$cf_logs" | grep -F 'v1.0.0'
grep -F 'FIPS mode enforced' <<<"$cf_logs" | grep -F 'true'
```

Run a request through the deployed client:

```shell
cf ssh crypto-broker-go-cli -c \
  "./app/go-client-cli hash-data \
  --profile=FIPS-140-3-128bit \
  'Welcome CryptoBroker'"
cf app crypto-broker-go-cli
```

Confirm that the application remains started after the request and that its
start time did not change.

Remove the test deployment after the result is recorded:

```shell
task cf-delete CLIENT=go
```

## Docker Compose

Build the server image with the selected FIPS module:

```shell
task docker-jaeger-build \
  BRANCH=main \
  TAG=fips-test \
  FIPS_MODE_MODULE_VERSION=v1.0.0
```

Start the containers in strict mode:

```shell
task docker-jaeger-deploy \
  CMD=up \
  TAG=fips-test \
  FIPS_GODEBUG_VALUE=fips140=only
```

Check the server and client logs:

```shell
docker logs crypto-broker-server 2>&1 \
  | grep -E 'FIPS mode is enabled|FIPS mode version|FIPS mode enforced'
docker logs test_app_go-hash --tail 20
```

Stop the deployment after the result is recorded:

```shell
task docker-jaeger-deploy CMD=down TAG=fips-test
```

## Kubernetes

Build the Docker Compose images first. Load the same image tag into Minikube so
that the server and clients use compatible source revisions.

```shell
task docker-jaeger-build \
  BRANCH=main \
  TAG=fips-test \
  FIPS_MODE_MODULE_VERSION=v1.0.0

minikube image load \
  ghcr.io/open-crypto-broker/test_app_js:fips-test \
  ghcr.io/open-crypto-broker/test_app_go:fips-test \
  ghcr.io/open-crypto-broker/server:fips-test
```

Deploy the Helm chart with strict mode enabled:

```shell
task kube-deploy \
  TAG=fips-test \
  FIPS_GODEBUG_VALUE=fips140=only
```

Wait for the deployment and check the logs:

```shell
kubectl rollout status deployment/crypto-broker-kube-broker \
  --namespace crypto-broker
kubectl logs deployment/crypto-broker-kube-broker \
  --namespace crypto-broker \
  --container server-app \
  | grep -E 'FIPS mode is enabled|FIPS mode version|FIPS mode enforced'
kubectl logs deployment/crypto-broker-kube-broker \
  --namespace crypto-broker \
  --container test-app-go-hashing \
  --tail 20
```

Remove the deployment after the result is recorded:

```shell
task kube-destroy
```

## Test results

The automated Docker Compose and Minikube validation ran on 2026-08-19. It used
server commit `402991d`, deployment validation commit `5c72c49`, Go FIPS module
`v1.0.0`, and runtime setting `fips140=only`.

- Docker Compose passed. The server reported FIPS enabled, version `v1.0.0`,
  and enforced mode. A `FIPS-140-3-128bit` SHA-256 request succeeded. The
  server restart count remained zero.
- Minikube `v1.38.1` passed. The server reported FIPS enabled, version
  `v1.0.0`, and enforced mode. A SHA-256 request using the packaged `Default`
  profile succeeded. The server restart count remained zero.
- Cloud Foundry is pending. Run the manual procedure above in a non-production
  space.

The [temporary validation run](https://github.com/open-crypto-broker/crypto-broker-deployment/actions/runs/32255578984)
also removed the Docker Compose deployment and Minikube cluster after the tests.
