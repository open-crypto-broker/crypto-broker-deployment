# kube-broker Helm chart

This chart deploys the crypto-broker **server** together with a set of **Go/JS test clients** (and an optional **stress-test runner**) into a single pod.
It is meant for local/integration testing on Minikube or a scratch cluster — not for production.
Clients talk to the server over a shared Unix socket (`socket-volume`, mounted at `/tmp`); test certificates are mounted at `/certificates` from a ConfigMap.

## Layout

```bash
kube-broker/
  Chart.yaml            chart metadata
  values.yaml           tunables (image tag, server, test clients, stress, ...)
  templates/            rendered Kubernetes resources
  files/certificates/   test-only certs embedded into a ConfigMap
  build/                image build context (not packaged with the chart)
```

- `values.yaml` is the file you normally edit. `cliTestApps` is a list — add or
  remove entries to change which client containers run.
- Set `cliStressApp.enabled=true` to swap the functional clients for the stress runner.
- Templates only need editing when a change cannot be expressed through
  `values.yaml`.
- `build/stress-client.Dockerfile` builds the stress image; it lives here for
  convenience and is excluded from the packaged chart via `.helmignore`.

## Deploy

The chart is wired into the repository `Taskfile.yaml`:

```shell
# load images into Minikube, then deploy (or run `task kube-up` for both)
task minikube-images TAG=dev
task kube-deploy TAG=dev

# stress variant
task kube-prepare-stress-test TAG=dev
task kube-deploy TAG=dev STRESS_ENABLED=true STRESS_CONCURRENT=100 STRESS_NUM=100
task kube-run-stress-test

# tear down
task kube-down
```

Or directly with Helm:

```shell
helm upgrade --install crypto-broker . \
  --namespace crypto-broker --create-namespace \
  --set imageTag=dev
```

Default deployment name: `crypto-broker-kube-broker` (namespace `crypto-broker`).

## Inspecting the cluster

```shell
# pods in the namespace
kubectl get pods -n crypto-broker

# logs of a specific container in the pod
kubectl logs deployment/crypto-broker-kube-broker -n crypto-broker -c crypto-broker-server
```

`k9s` ([docs](https://k9scli.io/)) is a convenient TUI alternative for browsing
namespaces, pods and per-container logs.
