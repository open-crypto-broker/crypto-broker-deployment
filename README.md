# Crypto Broker Deployment and End-to-End Testing

This repository features two purposes.
On the one hand, it describes how to deploy the Crypto Broker Server and how to use the Crypto Broker client libraries through CLI test applications, as well as how to run both on Cloud Foundry and Kubernetes.
On the other hand it can perform end-to-end tests which simulate the usage of the Crypto Broker Server and the different Crypto Broker Clients from a user perspective.

See the [FIPS deployment testing guide](doc/fips.md) to build the server
with a selected Go FIPS module and enforce strict mode on Cloud Foundry,
Kubernetes, or Docker Compose.

## Introduction

The workflow for deploying and testing the Crypto Broker involves several steps:

1. Manage the necessary source repositories: `task src:<repos>`
2. Build the server and client binaries: `task build:<component>`.
3. Deploy the binaries on the desired platform: `task deploy:<platform>`.
4. Run end-to-end tests to verify the deployment and client interactions: `task test:<commands>`.

## Cross Compilation

For several tasks it is possible to specify for which Operating System (GOOS) and Architecture (GOARCH) the software shall be build.
For a list of supported operating systems and architectures refer to the [Golang variables](https://github.com/golang/go/blob/master/src/internal/syslist/syslist.go).

For example to build the server binary for MacOS on ARM64, the following can be executed:

```bash
GOOS=darwin GOARCH=arm64 task build:server
```

## Source Repositories

The server and the CLI clients are built from clones of their own repositories, checked out next to this one.
The builds are delegated to each repository's own `build` task, so the build commands are defined once, in the repository that owns them.

Managing those sources is a separate, explicit step:

```bash
# Clone a repository that is missing (safe to re-run, does nothing if already present)
task src:clone:*

# Pull the latest state of the branch
task src:update:*

# Delete a repository that is no longer needed
task src:delete:*

# Show which branch, commit and tag each repository is on
task src:status
```

Where `*` can be one of: `server`, `cli-go`, or `cli-js`.

Day-to-day work should stay on `main` so that breakage between server, client and CLI shows up immediately.
To verify a release instead, pin a single repository to a tag:

```bash
# Pin the server repository to a specific tag
task src:pin:server REF=v0.5.0
```

`task src:update:*` returns a pinned repository to the tip of its branch.

> [!IMPORTANT]
> These clones are disposable build inputs. `task src:update:*` discards local changes without asking, so do not develop inside them.

For a first-time setup, `task initial-setup` clones every repository and builds the server and both clients in one run.

## End-to-End (E2E) Testing

The `Taskfile.yaml` file specifies, besides other tasks, end-to-end tests.
These end-to-end tests build the different binaries, starts them and then perform Known-Answer-Tests.
With these tests the complete message flow is visible from start to end.
Missing repositories are cloned automatically; existing ones are reused as-is, so run `task src:update:*` first when you want to test the latest state.

### Available Test Commands

A unified test command can be used to run specific E2E tests:

```bash
task test:clients:*
```

Where `*` can be one of: `health`, `benchmark`, `hash-data`, `encrypt-data`, or `sign-certificate`.

The following command performs all E2E tests with all combinations of clients and the server:

```bash
task test:all
```

These E2E tests are also executed in GitHub Actions.

### Clients Compatibility Matrix

The signing test command can build a compatibility matrix for each client, showing which profile supports which key-sizes for CSRs and also for the test Certificate Authority.
The command can take some time, since its complexity is O(n<sup>4</sup>): for each client, each profile will be tested and for each profile each CSR and for each CSR the different CA certificates will be tested.
The results are automatically gathered and are shown in a [table in the testing folder](testing/compatibility-matrix.md).

By default, the output is displayed on the console (stdout).
To generate a compatibility matrix file, set the `CREATE_COMP_MATRIX` parameter to `true`:

```bash
task test:clients:sign-certificate CREATE_COMP_MATRIX=true
```

## Deployment

### Cloud Foundry

#### Cloud Foundry Setup

As a prerequisite, the Cloud Foundry CLI needs to be installed locally. After that the CLI tool can be used to deploy an app to a Cloud Foundry instance. Please check the [Cloud Foundry Documentation](https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html) for the step by step guide on how to do that.

#### Cloud Foundry Deployment

The deployment of a Cloud Foundry app is managed via a [Cloud Foundry Manifest](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html) file.
The Crypto Broker Server is meant to be deployed as a Sidecar to the main app, which uses any of the Crypto Broker Clients to communicate with the Server via a unix socket on a shared filesystem between application and server (more on the [documentation repo](https://github.com/open-crypto-broker/crypto-broker-documentation)).

Two example Manifests can be found inside the [deployments folder](deployments/cloud-foundry/), both sharing the same sidecar. The only difference between the two is the client library used, one in Golang, the other one in NodeJs.

As it can be seen from the Manifest files, only two things are needed for deploying the Server as a sidecar:

* The server's compiled binary, which can be found on the [Releases](https://github.com/open-crypto-broker/crypto-broker-server/releases) of the Crypto Broker Server repository. Please select the appropriate architecture  (default Cloud Foundry instance is `amd64`).
* A `Profiles.yaml` file, which is [specified here](https://github.com/open-crypto-broker/crypto-broker-documentation/blob/main/spec/0002-profile-structure.md). The path to this file is then passed as an environment variable named `CRYPTO_BROKER_PROFILES_DIR` to the server. An [example profile](testing/profiles/Profiles.yaml) file is in the testing/profiles folder.

For simplicity, in the example manifests both binary and profile are located in the same folder as the `manifest.yaml` file. That way, they can be easily accessed by the CLI when deploying to Cloud Foundry.

To deploy the Crypto Broker Server, a test app, and the OpenTelemetry Collector (otel-collector) to Cloud Foundry, use the following task. Make sure you are logged in to your Cloud Foundry instance first:

```bash
task deploy:cf-push CLIENT=go
# or
task deploy:cf-push CLIENT=js
```

This will automatically copy the required binaries, profiles, certificates, and the otel-collector (with its configuration) into the deployment folder before pushing to Cloud Foundry.

To delete the deployment from Cloud Foundry, use:

```bash
task deploy:cf-delete CLIENT=go
# or
task deploy:cf-delete CLIENT=js
```

### Kubernetes

#### Kubernetes Setup

For deployment in Kubernetes, Kubernetes and Helm must be installed in terminal.
Kubernetes is installed with Docker-desktop, while Helm can be easily installed as per documentation [Helm Install](https://helm.sh/docs/intro/install/).

#### Kubernetes Deployment

These local docker images can be used to be loaded into [minikube](https://minikube.sigs.k8s.io/docs/) and to start with that the Kubernetes cluster.
Make sure that minikube is up and running (e.g. issue `minikube start`).
For deployment, simply run the following command (or equivalent directly from Taskfile):

```shell
# make sure that minikube is started
task deploy:kube-up
```

This will deploy the Helm chart `kube-broker` in the `crypto-broker` namespace in your local kubernetes cluster.
The cluster will spin up a server which listens on the Unix Socket and two CLI test apps that will send periodically requests (hash and sign) to the server.

To modify the parameters of the deployment, you can modify the values of the [values file](deployments/k8s/kube-broker/values.yaml).
This includes for example the image name and tag, the arguments for hashing and signing, the number of replicas and more.
Feel free to check the [Kubernetes Readme](deployments/k8s/kube-broker/README.md) for a more detailed explanation of the different values and configuration options that can be set.

To uninstall the Helm deployment run:

```shell
task deploy:kube-down
```

### Stress Testing

The CLI-Go stress benchmark must run in the deployed workload because clients
connect to the broker through a local Unix socket.

For Cloud Foundry:

```shell
task deploy:cf-push CLIENT=go
task deploy:cf-stress-test CONCURRENT=100 NUM=100
```

For Kubernetes:

```shell
task deploy:kube-prepare-stress-test TAG=v0.5.0
task deploy:kube-up TAG=v0.5.0 STRESS_ENABLED=true STRESS_CONCURRENT=100 STRESS_NUM=100
task deploy:kube-run-stress-test
```

### Docker Compose with Observability — Jaeger and Grafana

You can run Jaeger and Grafana (with Loki for logs) locally using Taskfile tasks provided in this repository.

Start Jaeger via Taskfile:

```bash
# Build images for Jaeger (if needed):
task deploy:docker-jaeger-build
# Start Jaeger:
task deploy:docker-jaeger-deploy CMD=up
# Stop Jaeger:
task deploy:docker-jaeger-deploy CMD=down
```

Start Grafana (LGTM) via Taskfile:

```bash
# Build Grafana images (optional):
task deploy:docker-grafana-build
# Start Grafana:
task deploy:docker-grafana-deploy CMD=up
# Stop Grafana:
task deploy:docker-grafana-deploy CMD=down
```

Quick notes:

* Grafana UI: ```http://localhost:3000``` (default login: admin / admin — a pre-built dashboard covering server metrics, traces, and logs is included)
* Jaeger UI: ```http://localhost:16686``` — browse traces and services

## Support, Feedback, Contributing

This project is open to feature requests/suggestions, bug reports etc. via [GitHub issues](https://github.com/open-crypto-broker/crypto-broker-deployment/issues). Contribution and feedback are encouraged and always welcome. For more information about how to contribute, the project structure, as well as additional contribution information, see our [Contribution Guidelines](CONTRIBUTING.md).

## Security / Disclosure

If you find any bug that may be a security problem, please follow our instructions at [in our security policy](https://github.com/open-crypto-broker/crypto-broker-deployment/security/policy) on how to report it. Please do not create GitHub issues for security-related doubts or problems.

## Code of Conduct

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone. By participating in this project, you agree to abide by its [Code of Conduct](https://github.com/open-crypto-broker/.github/blob/main/CODE_OF_CONDUCT.md) at all times.

## Licensing

Copyright 2025 SAP SE or an SAP affiliate company and Open Crypto Broker contributors. Please see our [LICENSE](LICENSE) for copyright and license information. Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/open-crypto-broker/crypto-broker-deployment).
