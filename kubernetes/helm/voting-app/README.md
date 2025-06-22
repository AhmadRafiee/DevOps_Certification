# Helm Example Repository

Voting application helm repository

## Get started

Add this repository to Helm.

```bash
helm repo add vote https://raw.githubusercontent.com/AhmadRafiee/DevOps_Certification/main/kubernetes/helm/voting-app
```

Update helm repository

```bash
helm repo update vote
```

Show helm values

```bash
helm show values vote/voting-app
```

Store all values on file
```bash
helm show values vote/voting-app > voting-app-values.yml
```

change these values and install hello world

Before Running the Command:
  - **Ensure Helm is Installed:** Make sure you have Helm installed on your system.
  - **Update Repositories:** You may want to update your Helm repositories to ensure you have the latest charts:
  - **Check Values File:** Verify that example-values.yml contains valid configuration settings for the chart.

Install an example.

```bash
helm install vote vote/voting-app --values voting-app-values.yml --namespace voting-app --create-namespace
```

**Explanation:**
  - **helm install:** The command to install a Helm chart.
  - **hello**: The name you are giving to this release.
  - **example/hello-world:** The chart you are installing.
  - **--values voting-app-values.yml:** Specifies a custom values file for configuration.
  - **--namespace voting-app:** Installs the chart in the voting-app namespace.
  - **--create-namespace:** Creates the namespace if it doesn’t exist.

[Reference](https://github.com/dockersamples/example-voting-app)