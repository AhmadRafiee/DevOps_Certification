# Helm Example Repository

Ahoy world!  I'm a Helm repository for example charts.

## Get started

Add this repository to Helm.

```bash
helm repo add example https://raw.githubusercontent.com/AhmadRafiee/DevOps_Certification/main/kubernetes/helm/hello-world
```

Update helm repository

```bash
helm repo update example
```

Show helm values

```bash
helm show values example/hello-world
```

Store all values on file
```bash
helm show values example/hello-world > example-values.yml
```

change these values and install hello world

Before Running the Command:
  - **Ensure Helm is Installed:** Make sure you have Helm installed on your system.
  - **Update Repositories:** You may want to update your Helm repositories to ensure you have the latest charts:
  - **Check Values File:** Verify that example-values.yml contains valid configuration settings for the chart.

Install an example.

```bash
helm install vote example/hello-world --values example-values.yml --namespace salam --create-namespace
```

**Explanation:**
  - **helm install:** The command to install a Helm chart.
  - **hello**: The name you are giving to this release.
  - **example/hello-world:** The chart you are installing.
  - **--values example-values.yml:** Specifies a custom values file for configuration.
  - **--namespace salam:** Installs the chart in the salam namespace.
  - **--create-namespace:** Creates the namespace if it doesn’t exist.

[Reference](https://github.com/helm/examples)