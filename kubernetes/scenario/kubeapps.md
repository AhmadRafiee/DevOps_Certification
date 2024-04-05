# Get Started with Kubeapps

Kubeapps is an in-cluster web-based application that enables users with a one-time installation to deploy, manage, and upgrade applications on a Kubernetes cluster.

This guide will walk you through the process of deploying Kubeapps for your cluster and installing an example application.

## Prerequisites

Kubeapps assumes a working Kubernetes cluster (v1.15+), as well as the [`helm`](https://helm.sh/docs/intro/install/) (3.1.0+) and [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/) command-line interfaces installed and configured to talk to your Kubernetes cluster. Kubeapps has been tested with Azure Kubernetes Service (AKS), Google Kubernetes Engine (GKE), `minikube` and Docker for Desktop Kubernetes. Kubeapps works on RBAC-enabled clusters and this configuration is encouraged for a more secure install.

> On GKE, you must either be an "Owner" or have the "Container Engine Admin" role in order to install Kubeapps.

## Step 1: Install Kubeapps

Use the Helm chart to install the latest version of Kubeapps:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
kubectl create namespace kubeapps
helm install kubeapps --namespace kubeapps bitnami/kubeapps
```

For detailed information on installing, configuring and upgrading Kubeapps, checkout the [chart README](https://github.com/kubeapps/kubeapps/tree/master/chart/kubeapps).

The above commands will deploy Kubeapps into the `kubeapps` namespace in your cluster. It may take a few minutes to execute. Once it has been deployed and the Kubeapps pods are running, continue to step 2.

## Step 2: Create a demo credential with which to access Kubeapps and Kubernetes

For any user-facing installation you should [configure an OAuth2/OIDC provider](./using-an-OIDC-provider.md) to enable secure user authentication with Kubeapps and the cluster, but this is quite an overhead to simply try out Kubeapps. Instead, for a simpler way to try out Kubeapps for personal learning, we can create a Kubernetes service account and use that API token to authenticate with the Kubernetes API server via Kubeapps:

```bash
kubectl create --namespace default serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
```

> **NOTE** It's not recommended to assign users the `cluster-admin` role for Kubeapps production usage. Please refer to the [Access Control](./access-control.md) documentation to configure fine-grained access control for users.

To retrieve the token,

### On Linux/macOS:

```bash
kubectl get --namespace default secret $(kubectl get --namespace default serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo
```

### On Windows:

Create a file called `GetDashToken.cmd` with the following lines in it:

```bat
@ECHO OFF
REM Get the Service Account
kubectl get --namespace default serviceaccount kubeapps-operator -o jsonpath={.secrets[].name} > s.txt
SET /p ks=<s.txt
DEL s.txt

REM Get the Base64 encoded token
kubectl get --namespace default secret %ks% -o jsonpath={.data.token} > b64.txt

REM Decode The Token
DEL token.txt
certutil -decode b64.txt token.txt
```

Open a command prompt and run the `GetDashToken.cmd` Your token can be found in the `token.txt` file.

## Step 3: Start the Kubeapps Dashboard

Once Kubeapps is installed, securely access the Kubeapps Dashboard from your system by running:

```bash
kubectl port-forward -n kubeapps svc/kubeapps 8080:80
```

This will start an HTTP proxy for secure access to the Kubeapps Dashboard. Visit http://127.0.0.1:8080/ in your preferred web browser to open the Dashboard. Here's what you should see:

![Dashboard login page](../images/dashboard-login.png)

Paste the token generated in the previous step to authenticate and access the Kubeapps dashboard for Kubernetes.

![Dashboard main page](../images/dashboard-home.png)

**_Note:_** If you are setting up Kubeapps for other people to access, you will want to use a different service type or setup Ingress rather than using the above `kubectl port-forward`. For detailed information on installing, configuring and upgrading Kubeapps, checkout the [chart README](https://github.com/kubeapps/kubeapps/tree/master/chart/kubeapps)

## Step 4: Deploy WordPress

Once you have the Kubeapps Dashboard up and running, you can start deploying applications into your cluster.

- Use the "Deploy" button or click on the "Catalog" page in the Dashboard to select an application from the list of charts in any of the configured Helm chart repositories. This example assumes you want to deploy WordPress.

  ![WordPress chart](../images/wordpress-search.png)

- Click the "Deploy" button.

  ![WordPress chart](../images/wordpress-chart.png)

- You will be prompted for the release name and values for the application. The form is populated by the values (YAML), which you can see in the adjacent tab.

  ![WordPress installation](../images/wordpress-installation.png)

- Click the "Deploy" button. The application will be deployed. You will be able to track the new Helm deployment directly from the browser. The status will be shown at the top, including the access URL and any secret included with the app. You can also look at the individual resources lower in the page. It will also show the number of ready pods. If you run your cursor over the status, you can see the workloads and number of ready and total pods within them.

  ![WordPress deployment](../images/wordpress-deployment.png)

To access your new WordPress site, you can run the commands in the "Notes" section to get the URLs or simply click a URL (HTTP and HTTPS) shown.

**_Note:_** Depending on your cloud provider of choice, it may take some time for an access URL to be available for the application and the Service will stay in a "Pending" state until a URL is assigned. If using Minikube, you will need to run `minikube tunnel` in your terminal in order for an IP address to be assigned to your application.

![WordPress deployment notes](../images/wordpress-url.png)

To get the credentials for logging into your WordPress account, refer to the "Notes" section. You can also get the WordPress password by clicking on the eye next to `wordpress-password`.

![WordPress deployment notes](../images/wordpress-credentials.png)

## [Optional] Step 5: Uninstall/Delete WordPress

If you want to uninstall/delete your WordPress application, you can do so by clicking the "Delete" button.

![WordPress uninstall](../images/wordpress-uninstall.png)

# Using the Dashboard

Once you have [installed Kubeapps in your cluster](https://github.com/kubeapps/kubeapps/tree/master/chart/kubeapps) you can use the Dashboard to start managing and deploying applications in your cluster. Checkout the [Getting Started](./getting-started.md) guide to learn how to access the Dashboard and deploy your first application.

The following sections walk you through some common tasks with the Kubeapps Dashboard.

## Work with Charts

### Deploy new applications using the Dashboard

- Start with the Dashboard welcome page:

  ![Dashboard main page](../images/dashboard-home.png)

- Use the "Catalog" menu to select an application from the list of applications available. This example assumes you want to deploy MariaDB.

  ![MariaDB chart](../images/mariadb-chart.png)

- Click the "Deploy" button. You will be prompted for the release name, cluster namespace and values for your application deployment.

  ![MariaDB installation](../images/mariadb-installation.png)

- Click the "Submit" button. The application will be deployed. You will be able to track the new Kubernetes deployment directly from the browser. The "Notes" section of the deployment page contains important information to help you use the application.

  ![MariaDB deployment](../images/mariadb-deployment.png)

### List all the applications running in your cluster

The "Applications" page displays a list of the application deployments in your cluster.

![Deployment list](../images/dashboard-deployments.png)

### Remove existing application deployments

You can remove any of the applications from your cluster by clicking the "Delete" button on the application's status page:

![Deployment removal](../images/dashboard-delete-deployment.png)

### Add more chart repositories

By default, Kubeapps comes with the Bitnami repository enabled. You can see the list of enabled chart repositories in the "App Repositories" page under the menu:

![Repositories List](../images/dashboard-repos.png)

Add new repositories (for example, your organization's chart repository) by clicking the "Add App Repository" button. Fill the "Add Repository" form using the repository info. For a detailed guide of how to add app repositories, check [this guide](./private-app-repository.md).

![Adding repository](../images/dashboard-add-repo.png)