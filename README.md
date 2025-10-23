# Crypto Broker Deployment and End-to-End Testing

This repository features two purposes.
On the one hand it describes how the Crypto Broker Server and the different Crypto Broker Clients can be deployed to Cloud Foundry and Kubernetes.
On the other hand it can perform end-to-end tests which simulate the usage of the Crypto Broker Server and the different Crypto Broker Clients from a user perspective.

## Cross Compilation and Branch Support

For several tasks it is possible to specify for which Operating System (OS) and Architecture (ARCH) the software shall be build.
For a list of supported operating systems and architectures refer to the [Golang variables](https://github.com/golang/go/blob/master/src/internal/syslist/syslist.go).
Additionally, for some tasks a BRANCH variable can be specified in order to build the software from a specific branch.
For a list of tasks which support these options, issue the task overview with:

```bash
task
# or
task -l
```

## Deployment

### Cloud Foundry

#### Cloud Foundry Setup

As a prerequisite, the Cloud Foundry CLI needs to be installed locally. After that the CLI tool can be used to deploy an app to a Cloud Foundry instance. Please check the [Cloud Foundry Documentation](https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html) for the step by step guide on how to do that.

#### Cloud Foundry Deployment

The deployment of a Cloud Foundry app is managed via a [Cloud Foundry Manifest](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html) file.
The Crypto Broker Server is meant to be deployed as a Sidecar to the main app, which uses any of the Crypto Broker Clients to communicate with the Server via a unix socket on a shared filesystem between Client and Server (more on the [documentation repo](https://github.com/open-crypto-broker/crypto-broker-documentation)).

Two example Manifests can be found inside the [deployments folder](deployments/cloud-foundry/), both sharing the same sidecar. The only difference between the two is the client library used, one in Golang, the other one in NodeJs.

As it can be seen from the Manifest files, only two things are needed for deploying the Server as a sidecar:

* The server's compiled binary, which can be found on the [Releases](https://github.com/open-crypto-broker/crypto-broker-server/releases) of the Crypto Broker Server repository. Please select the appropriate architecture  (default Cloud Foundry instance is `amd64`).
* A `Profiles.yaml` file, which is [specified here](https://github.com/open-crypto-broker/crypto-broker-documentation/blob/main/spec/0002-profile-structure.md). The path to this file is then passed as an environment variable named `CRYPTO_BROKER_PROFILES_DIR` to the server. An [example profile](testing/profiles/Profiles.yaml) file is in the testing/profiles folder.

For simplicity, in the example manifests both binary and profile are located in the same folder as the `manifest.yaml` file. That way, they can be easily accessed by the CLI when deploying to Cloud Foundry.

In order to deploy the Crypto Broker Server and one of the Crypto Broker Clients, the following task can be executed specifying which client should be deployed.
A prerequisite is, that the login to the Cloud Foundry instance happened already.

```bash
task deploy-cf-cryptobroker CLIENT=go
# or
task deploy-cf-cryptobroker CLIENT=js
```

### Docker-Compose and Kubernetes

#### Kubernetes Setup

For deployment in Kubernetes, Kubernetes and Helm must be installed in terminal. Kubernetes is installed with Docker-desktop, while Helm can be easily installed as per documentation [Helm Install](https://helm.sh/docs/intro/install/). Optionally, for deploying on a custom Kubernetes Cloud Cluster, you might need to setup your local `.env` file and change it to write your own user information (see above).

Please, DO NOT share this file with anybody or upload it anywhere. This file should only be stored locally in your computer and will be read each time you run a `task` command.

#### Docker-Compose and Kubernetes Deployment

For a local docker deployment first the Crypto Broker server and the respective clients must be build with the build tasks (see `task build-client` and `task build-crypto-broker-server`).
After that the docker-compose files in the `deployments/docker` folder can be used to build a local docker-compose.
The tasks to build it are as follows:

```shell
task docker-compose-build
task docker-compose-deploy
```

The `task docker-compose-deploy` will automatically start the compose setup and the output is logged to console.
In order to stop the docker-compose deployment exit it with `ctrl+c`.

These local docker images can be used to be loaded into [minikube](https://minikube.sigs.k8s.io/docs/) and to start with that the Kubernetes cluster.
For deployment, simply run the following command (or equivalent directly from Taskfile):

```shell
task minikube-images
task kube-deploy
```

This will deploy the Helm chart `kube-broker` in the `crypto-broker` namespace in your local kubernetes cluster. The cluster will spin up a server which listens on the Unix Socket and two clients that will send periodically requests (hash and sign) to the server.

To modify the parameters of the deployment, you can modify the values of the [values file](deployments/k8s/kube-broker/values.yaml). This includes for example the image name and tag, the arguments for hashing and signing, the number of replicas and more. Feel free to check the [Kubernetes Readme](deployments/k8s/kube-broker/README.md) for a more detailed explanation of the different values and configuration options that can be set.

To uninstall the Helm deployment run:

```shell
task kube-destroy
```

## End-to-End (E2E) Testing

The `Taskfile.yaml` file specifies, besides other tasks, end-to-end tests.
These end-to-end tests clone the different repositories, builds them, starts them and then perform Known-Answer-Tests for hashing or signing a certificate.
With these tests the complete message flow is visible from start to end.

The following command performs all tests with all combinations of clients and the server:

```bash
task test-clients
```

The E2E hashing tests for all clients and server can be executed with:

```bash
task test-hash-clients
```

The E2E signing tests for all clients and server are executed with:

```bash
task test-sign-clients
```

These E2E tests are also executed in GitHub Actions.
During these E2E tests the repositories are built and still available after testing.
In order to clean everything up, the following task can be used:

```bash
task delete-all
```

## Support, Feedback, Contributing

This project is open to feature requests/suggestions, bug reports etc. via [GitHub issues](https://github.com/open-crypto-broker/crypto-broker-deployment/issues). Contribution and feedback are encouraged and always welcome. For more information about how to contribute, the project structure, as well as additional contribution information, see our [Contribution Guidelines](CONTRIBUTING.md).

## Security / Disclosure

If you find any bug that may be a security problem, please follow our instructions at [in our security policy](https://github.com/open-crypto-broker/crypto-broker-deployment/security/policy) on how to report it. Please do not create GitHub issues for security-related doubts or problems.

## Code of Conduct

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone. By participating in this project, you agree to abide by its [Code of Conduct](https://github.com/open-crypto-broker/.github/blob/main/CODE_OF_CONDUCT.md) at all times.

## Licensing

Copyright 2025 SAP SE or an SAP affiliate company and Open Crypto Broker contributors. Please see our [LICENSE](LICENSE) for copyright and license information. Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/open-crypto-broker/crypto-broker-deployment).
