# Kubernetes Development

## Helm Chart

Helm Charts define a way to easily deploy and test Kubernetes apps in a controlled environment. They are used both in testing and production, as they simplify the work and allow us to use Infrastructure as Code (IaC) easily.

For working with a Helm Chart, it is important to know the following files:

- `Chart.yaml`: This file defines the basis of the Chart, as well as its dependencies with external Charts. As a developer, it is highly likely that you do not need to modify this file unless you want to add new dependencies based on other Helm Charts.
- `values.yaml`: This is the most important file when developing. This file allows you to define custom values for the resources inside the `templates` folder. This allows developers to experiment with different configurations, like changing the Docker image, the tags, the number of replicas, the mounted drives and more.
- `templates`: This folder defines the actual Kubernetes resources that will be deployed, with their values referencing the above mentioned `values.yaml` file. In general, these files should only be changed when there is no parameter that can be changed through the `values.yaml` file.
- `.helmignore`: Similar to .gitignore, this file is used by the Helm builder to ignore certain files when building a package.

## Interacting with your cluster

For testing the cluster, you can either use `kubectl` commands [Docs](https://kubernetes.io/docs/reference/kubectl/) or the `k9s` CLI tool [Docs](https://k9scli.io/). In each respective documentation you will find extensive use on how to use them, the basic commands and the whole reference. Note that `kubectl` is installed by default with all Kubernetes installations, but `k9s` needs to be installed additionally.

Basic default info when deployed:

- Namespace: crypto-broker
- Deployment name: broker-kube-broker
- Replica count: 1
- Containers inside each Pod: 3, two clients and one server

The most basic `kubectl` commands you will use are:

```shell
# list the pods in the given namespace NS
kubectl get pods -n NS

# outputs the logs of a pod POD_NAME in the NS namespace. The POD_NAME is retrieved with the get command
kubectl logs POD_NAME -n NS

# outputs the description of a pod POD_NAME in the NS namespace. The POD_NAME is retrieved with the get command
kubectl describe pod POD_NAME -n NS
```

On the other side, all this information can be also easily retrieved through `k9s`. Once you run it from terminal, use `:` to open the command line inside. There, you can change namespaces by typing `namespace NS` where NS is the name of the namespace you are looking for. From there, you can use the commands displayed on top of the CLI to interact with the Pods.
For example, you can press `d` to display the description. If you press `Enter`, you will see the multiple containers inside. From there, using `l` will display the logs of each container.
