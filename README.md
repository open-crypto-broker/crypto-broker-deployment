# Crypto Broker Deployment and End-to-End Testing

The Crypto Broker Deployment repository features two purposes, on the one hand deployment to specific targets and on the other hand end-to-end testing.
Additionally, it provides instructions how to cross-compile the server and client binaries for different operating systems and architectures.
Furthermore, it includes guidance for FIPS deployment testing.

## Introduction

The workflow for deploying and testing the Crypto Broker involves several steps:

1. Manage the necessary source repositories: `task src:<repos>`
2. Build the server and client binaries: `task build:<component>`.
3. Run end-to-end tests to verify the deployment and client interactions: `task test:<commands>`.
4. Deploy the binaries on the desired target: `task deploy:<target>`.

## Source Repository Management

The server and the CLI clients are built from clones of their own repositories, checked out into this folder.
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

## Build Management

Once the source repositories are cloned, the next step is to build the necessary binaries using the appropriate build tasks.
The build tasks are defined in each repository's own `Taskfile.yaml` and are invoked through the top-level `task build:<component>` commands.
For example, to build the server binary, run:

```bash
task build:server
```

Similarly, to build the CLI clients, run:

```bash
task build:cli-go
task build:cli-js
```

In order to build all binaries at once, the following command can be used:

```bash
task build:all
```

### Cross Compilation

It is possible to specify for which Operating System (GOOS) and Architecture (GOARCH) the software shall be build for the Go binaries.
For a list of supported operating systems and architectures refer to the [Golang variables](https://github.com/golang/go/blob/master/src/internal/syslist/syslist.go).

For example to cross-compile the server binary for MacOS on ARM64, the following can be executed:

```bash
GOOS=darwin GOARCH=arm64 task build:server
```

### FIPS140-3 Compilation and Deployment

Additionally, the FIPS140-3 enabled build can be controlled through the corresponding environment variable.
In order to enable FIPS-specific builds, set the appropriate environment variables in the `.env` file in the cloned `crypto-broker-server` repository before invoking the build task.
The values defined in the `.env` file will be automatically loaded and used during the build process.
For more details on the available environment variables and their usage, refer to the [server FIPS documentation](https://github.com/open-crypto-broker/crypto-broker-server/blob/main/docs/fips.md) in the `crypto-broker-server` repository.
The crucial part is, that there are two mechanisms to enable FIPS140-3 compliant builds: on the one hand a build-time variable which specifies which version of the FIPS certified crypto module to use, and on the other hand a runtime variable which ensures how the FIPS mode is enforced during execution.
When deploying to a specific target, it is important to ensure that both the build-time and runtime FIPS variables are set before building the binaries and also when deploying it to the target environment.

## End-to-End (E2E) Test Management

After building the binaries with the appropriate FIPS140-3 settings, the end-to-end tests can be executed to verify the complete message flow.
The end-to-end tests start the different binaries and then perform Known-Answer-Tests.
With these tests the complete message flow is visible from start to end.

### Available Test Commands

A unified test command can be used to run specific E2E tests for all clients:

```bash
task test:clients:*
```

Where `*` can be one of: `health`, `benchmark`, `hash-data`, `encrypt-data`, or `sign-certificate`.

The following command performs all E2E tests with all combinations of clients and the server:

```bash
task test:all
```

Each night, these E2E tests are also executed in GitHub Actions.

### Clients Compatibility Matrix

The signing test command can build a compatibility matrix for each client, showing which profile supports which key-sizes for CSRs and also for the test Certificate Authority.
The command can take some time, since its complexity is O(n<sup>4</sup>): for each client, each profile will be tested and for each profile each CSR and for each CSR the different CA certificates will be tested.
The results are automatically gathered and are shown in a [table in the testing folder](testing/compatibility-matrix.md).

By default, the output is displayed on the console (stdout).
To generate a compatibility matrix file, set the `CREATE_COMP_MATRIX` parameter to `true`:

```bash
task test:clients:sign-certificate CREATE_COMP_MATRIX=true
```

## Deployment Management

Before deploying, ensure that the binaries are correctly built.
For example, if you want to test the FIPS140-3 enabled version, make sure that the `crypto-broker-server` binary is built with the appropriate flags and environment variables to enable FIPS mode.
The following sections provide guidance for deploying the Crypto Broker Server to various environments, starting with Cloud Foundry.

### Cloud Foundry

#### Cloud Foundry Setup

As a prerequisite, the Cloud Foundry CLI needs to be installed locally.
After that the CLI tool can be used to deploy an app to a Cloud Foundry instance.
Please check the [Cloud Foundry Documentation](https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html) for the step by step guide on how to do that.

#### Cloud Foundry Deployment

The deployment of a Cloud Foundry app is managed via a [Cloud Foundry Manifest](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html) file.
The Crypto Broker Server is meant to be deployed as a Sidecar to the main app, which uses any of the Crypto Broker Clients to communicate with the Server via a unix socket on a shared filesystem between application and server (more on the [documentation repo](https://github.com/open-crypto-broker/crypto-broker-documentation)).

Two example Manifests can be found inside the [deployments folder](deployments/cloud-foundry/), both sharing the same sidecar. The only difference between the two is the client library used, one in Golang, the other one in NodeJs.

As it can be seen from the Manifest files, only two things are needed for deploying the Server as a sidecar:

* The server's compiled binary, which can be found on the [Releases](https://github.com/open-crypto-broker/crypto-broker-server/releases) of the Crypto Broker Server repository. Please select the appropriate architecture  (default Cloud Foundry instance is `amd64`).
* A `Profiles.yaml` file, which is [specified here](https://github.com/open-crypto-broker/crypto-broker-documentation/blob/main/spec/0002-profile-structure.md). The path to this file is then passed as an environment variable named `CRYPTO_BROKER_PROFILES_DIR` to the server. An [example profile](testing/profiles/Profiles.yaml) file is in the testing/profiles folder.

For simplicity, in the example manifests both binary and profile are located in the same folder as the `manifest.yaml` file.
That way, they can be easily accessed by the CLI when deploying to Cloud Foundry.

To deploy the Crypto Broker Server, a test app, and the OpenTelemetry Collector (otel-collector) to Cloud Foundry, use the following tasks.
Make sure you are logged in to your Cloud Foundry instance first:

```bash
# Build the required binaries
task build:all
# Deploy to Cloud Foundry
task deploy:cf-push:cli-go
# or
task deploy:cf-push:cli-js
```

The deploy task will automatically copy the required binaries, profiles, certificates, and the otel-collector (with its configuration) into the deployment folder before pushing to Cloud Foundry.

To delete the deployment from Cloud Foundry, use:

```bash
task deploy:cf-delete:cli-go
# or
task deploy:cf-delete:cli-js
```

### Kubernetes

#### Kubernetes Setup

For deployment in Kubernetes, Kubernetes, Helm, and minikube must be installed locally.

#### Kubernetes Deployment

These local docker images can be used to be loaded into [minikube](https://minikube.sigs.k8s.io/docs/) and to start with that the Kubernetes cluster.
Make sure that minikube is up and running (e.g. issue `minikube start`).
Build the required docker images and load them into minikube.
This can be done using the following Taskfile commands:

```shell
task deploy:kube:build:*
task deploy:kube:load:*
task deploy:kube:up
```

This will deploy the Helm chart `kube-broker` in the `crypto-broker` namespace in your local minikube Kubernetes cluster.
The cluster will spin up the Crypto Broker server which listens on the Unix Socket and CLI test apps that will send periodically requests (hash and sign) to the server.

To modify the parameters of the deployment, you can modify the values of the [values file](deployments/k8s/kube-broker/values.yaml).
This includes for example the image name and tag, the arguments for hashing and signing, the number of replicas and more.
Feel free to check the [Kubernetes Readme](deployments/k8s/kube-broker/README.md) for a more detailed explanation of the different values and configuration options that can be set.

To uninstall the Helm deployment run:

```shell
task deploy:kube:down
```

### Docker Compose with Observability — Jaeger and Grafana

In order to test the observability setup, there is a deployment which uses `docker compose` for running Jaeger and Grafana locally.

Deployment of Grafana or Jaeger via Taskfile:

```bash
# Build images (if needed):
task deploy:docker:*:build
# Start docker compose setup:
task deploy:docker:*:up
# Stop docker compose setup:
task deploy:docker:*:down
```

Where `*` can be replaced with either `jaeger` or `grafana` depending on which service you want to manage.

The WebUI for the observability tools can be accessed as follows:

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
