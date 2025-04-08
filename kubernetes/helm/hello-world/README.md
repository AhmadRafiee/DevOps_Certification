# Helm Example Repository

Ahoy world!  I'm a Helm repository for example charts.

## Get started

Add this repository to Helm.

```
helm repo add example https://github.com/AhmadRafiee/DevOps_Certification/tree/main/kubernetes/helm/hello-world
```

Update helm repository

```
helm repo update example
```

Show helm values

```
helm show values example/hello-world
```

change these values and install hello world

Before Running the Command:
  - **Ensure Helm is Installed:** Make sure you have Helm installed on your system.
  - **Update Repositories:** You may want to update your Helm repositories to ensure you have the latest charts:
  - **Check Values File:** Verify that example-values.yml contains valid configuration settings for the chart.

Install an example.

```
helm install hello example/hello-world --values example-values.yml --namespace salam --create-namespace
```

**Explanation:**
  - **helm install:** The command to install a Helm chart.
  - **hello**: The name you are giving to this release.
  - **example/hello-world:** The chart you are installing.
  - **--values example-values.yml:** Specifies a custom values file for configuration.
  - **--namespace salam:** Installs the chart in the salam namespace.
  - **--create-namespace:** Creates the namespace if it doesn’t exist.