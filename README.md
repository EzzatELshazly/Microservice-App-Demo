# Python Microservice Deployment on Azure AKS

## Overview

This project demonstrates a complete end-to-end deployment of a Python microservice on Azure Kubernetes Service (AKS) using Infrastructure as Code (Terraform), GitOps (ArgoCD), CI/CD (GitHub Actions), and comprehensive monitoring (Prometheus, Loki, Grafana).

## Architecture

- **Cloud Provider**: Microsoft Azure
- **Container Orchestration**: Azure Kubernetes Service (AKS)
- **Container Registry**: Azure Container Registry (ACR)
- **Infrastructure as Code**: Terraform
- **GitOps**: ArgoCD
- **CI/CD**: GitHub Actions
- **Ingress Controller**: NGINX Ingress Controller
- **Certificate Management**: Cert-Manager with Let's Encrypt
- **Monitoring**: Prometheus, Loki, Grafana

<img width="6800" height="4567" alt="task drawio" src="https://github.com/user-attachments/assets/35ffb922-ae63-4db2-b80e-f464bd1a806f" />


## Architecture Workflow

1. Developer pushes code to main branch
2. GitHub Actions builds Docker image and pushes to ACR
3. GitHub Actions updates Kubernetes manifest with new image tag
4. ArgoCD detects manifest change and syncs deployment
5. New pods are deployed to AKS cluster
6. NGINX Ingress routes traffic to new pods
7. Metrics and logs are collected by Prometheus and Loki
8. Grafana displays monitoring data and logs
9.Automated infrastructure provisioning with Terraform

## Prerequisites

### Required Tools Installation

Install Azure CLI:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Install kubectl:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Install Terraform:

```bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

Install Helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Install ArgoCD CLI:

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

### Azure Authentication

Login to Azure CLI:

```bash
az login
```

Verify authentication:

```bash
az account show
```
<img width="976" height="430" alt="image" src="https://github.com/user-attachments/assets/9f3010c7-104d-4065-8300-db70a8271f2b" />


## Phase 1: Dockerize the Application

Create a Dockerfile in your repository root with the following specifications:

- Base image: Python 3.11 slim
- Working directory: /app
- Exposed port: 5000
- Entry point: run.py

## Phase 2: Infrastructure Provisioning with Terraform

### Infrastructure Components

The Terraform configuration creates the following Azure resources:

- Resource Group
- Azure Kubernetes Service (AKS) cluster with auto-scaling
- Azure Container Registry (ACR)
- Storage Account for Terraform state management
- Storage Container for state files
- Role assignments for AKS to pull from ACR

### Terraform Configuration Files

Create the following files in the `terraform/` directory:

- **main.tf**: Defines AKS cluster, ACR, storage account, and role assignments
- **variables.tf**: Contains configurable variables for resource names and specifications
- **outputs.tf**: Exports important values like kubeconfig, ACR credentials
- **provider.tf**: Configures Azure provider and remote backend

> [!Important]
>  Terraform Initialization Order, Due to the remote backend dependency, follow this specific initialization sequence because You cannot use a remote backend until the storage account exists.

1. Temporarily comment out the `backend "azurerm"` block in provider.tf
2. Initialize and apply Terraform:

```bash
cd terraform/
terraform init
```
<img width="1101" height="678" alt="terraform init" src="https://github.com/user-attachments/assets/f93bf3c8-9709-4e8c-86e2-4cd7c3c9b625" />
```bash
terraform plan
```
<img width="1877" height="856" alt="terraform plan" src="https://github.com/user-attachments/assets/a4bda84b-a997-4224-8d11-232ced1caccc" />

```bash
terraform apply
```
<img width="1867" height="922" alt="terraform apply" src="https://github.com/user-attachments/assets/d3bfe460-cda8-422c-99cb-c3e06d18cd15" />

3. After resources are created, uncomment the backend block
4. Reinitialize with state migration:

```bash
terraform init -migrate-state
```
<img width="1406" height="758" alt="terraform after we created backend " src="https://github.com/user-attachments/assets/5843e33a-36c2-4d03-9ade-6f73104a724d" />

5. Recources screenshot in azure. 
# Recource Groups created after terrafrom apply.
<img width="1276" height="561" alt="rg created after terrafrom apply" src="https://github.com/user-attachments/assets/5394422c-0b90-41ad-9dc5-2967c65c13bf" />
# resources under rg-aks-microservice ( ACR, AKS, Storage account )
<img width="1563" height="655" alt="image" src="https://github.com/user-attachments/assets/77c33b8e-11a7-444e-ab19-e5fc69b010c7" />


### Retrieve AKS Credentials

```bash
az aks get-credentials --resource-group rg-aks-microservice --name aks-microservice-cluster
```

Verify connection:

```bash
kubectl get nodes
```

## Phase 3: Kubernetes Manifests

### Create Namespace

Apply the namespace configuration to create the `microservice` namespace.

### Deployment Configuration

The deployment manifest specifies:

- 1 replica (scalable)
- Container image from ACR
- Port 5000 exposure
- Labels for service discovery

### Service Configuration

The service manifest creates:

- ClusterIP service type
- Port mapping: 80 to 5000
- Selector matching deployment labels

### Ingress Configuration

The ingress manifest configures:

- NGINX ingress class
- Domain routing

## Phase 4: GitOps with ArgoCD

### Install ArgoCD

Create ArgoCD namespace and install:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
### make sure that argo is installed correctly 
```bash
kubectl get all -n argocd
```
<img width="1806" height="972" alt="image" src="https://github.com/user-attachments/assets/b0d2d64d-a054-4f33-8a69-fd0718b233e0" />

### Expose ArgoCD Server

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

### Retrieve Admin Credentials

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

Get the external IP:

```bash
kubectl get svc argocd-server -n argocd
```

Access ArgoCD UI using:
<img width="1917" height="970" alt="image" src="https://github.com/user-attachments/assets/478b3188-21da-41d8-b5ac-32504f86feac" />

- Username: admin
- Password: (from previous command)

## Phase 5: NGINX Ingress Controller

### Install NGINX Ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.publishService.enabled=true \
  --set controller.service.externalTrafficPolicy=Local
```

### Verify Installation

```bash
kubectl get all -n ingress-nginx
```
<img width="1860" height="338" alt="image" src="https://github.com/user-attachments/assets/946421c3-57b6-457a-9e35-926f1ce4ba4f" />

## Phase 6: SSL Certificate Management

### Install Cert-Manager

```bash
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.15.1 \
  --set installCRDs=true
```

### Verify Installation

```bash
kubectl get pods -n cert-manager
```

### Create ClusterIssuer

Create a ClusterIssuer manifest for Let's Encrypt production with:

- ACME server endpoint
- Email for certificate notifications
- HTTP-01 challenge solver with NGINX ingress

Apply the ClusterIssuer:

```bash
kubectl apply -f cluster-issuer.yaml
```

### Configure DNS

1. Navigate to the NGINX Ingress Controller's public IP in Azure Portal
<img width="1895" height="762" alt="image" src="https://github.com/user-attachments/assets/d929ca3f-cc89-44cb-90a8-7e2e2a99bf5f" />
2. Go to Configuration section
3. Create a DNS name label (e.g., pythontask)
<img width="1883" height="583" alt="image" src="https://github.com/user-attachments/assets/79c825c7-b76d-449d-9d4d-cf02c25a4086" />
4. The full domain will be: `{dns-label}.{region}.cloudapp.azure.com`

### Update Ingress for TLS

The ingress manifest includes:

- cert-manager.io/cluster-issuer annotation
- TLS section with host and secret name
- Force SSL redirect annotation

Sync in ArgoCD to apply changes.

### Verify Certificate

```bash
kubectl get certificate -n microservice
```
<img width="992" height="78" alt="image" src="https://github.com/user-attachments/assets/3a8ee171-5ab6-4724-b703-7d4c01448644" />

The application is now accessible via HTTPS.

<img width="1542" height="704" alt="Screenshot (229)(1)" src="https://github.com/user-attachments/assets/9ad690fe-e3ec-4c1d-ba89-83106e30e5c0" />


## Phase 7: CI/CD Pipeline with GitHub Actions

### Configure GitHub Repository

1. Navigate to Settings > Actions > General
2. Under Workflow permissions, select "Read and write permissions"
3. Enable "Allow GitHub Actions to create and approve pull requests"
4. Save changes

### Add GitHub Secrets

Navigate to Settings > Secrets and variables > Actions and add:

- **ACR_USERNAME**: Azure Container Registry username
- **ACR_PASSWORD**: Azure Container Registry password

### CI/CD Pipeline Workflow

The GitHub Actions workflow includes two jobs:

**Build and Push Job:**

- Checks out code
- Generates image tag from branch name and commit SHA
- Authenticates to ACR
- Sets up Docker Buildx
- Builds and pushes image to ACR with tags

### Navigate to acr in azure portal > services > Repositories 
<img width="1857" height="750" alt="image" src="https://github.com/user-attachments/assets/3d8527d1-a2e1-488d-8054-b7b889ce0e33" />

**Update Manifest Job:**

- Checks out code with write permissions
- Updates deployment.yaml with new image tag
- Commits and pushes changes to trigger ArgoCD sync

<img width="1447" height="52" alt="image" src="https://github.com/user-attachments/assets/828372ac-c66f-4bf7-9720-796c561d327f" />

### Workflow Triggers

The pipeline runs automatically on push to the main branch.
<img width="1877" height="562" alt="image" src="https://github.com/user-attachments/assets/125b4e29-7303-4c93-a3c5-0165da6ceb01" />


## Phase 8: Monitoring Stack

### Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

### Install Prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set server.service.type=ClusterIP \
  --set alertmanager.enabled=false \
  --set prometheus-pushgateway.enabled=false
```

### Install Loki Stack

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set loki.enabled=true \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=5Gi
```

### Install Grafana

Create a values file for Grafana with:

- ClusterIP service type
- Pre-configured datasources for Prometheus and Loki
- Persistence disabled for simplicity

then Install Grafana with Pre-configured Datasources loki and promethoius
vim values grafana-values.yaml
```bash
service:
  type: ClusterIP

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server
      access: proxy
      isDefault: true
    - name: Loki
      type: loki
      url: http://loki:3100
      access: proxy
      isDefault: false

persistence:
  enabled: false

admin:
  existingSecret: ""
  userKey: admin-user
  passwordKey: admin-password
```
Install Grafana:

```bash
helm install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana-values.yaml
```

### Verify Monitoring Stack

```bash
kubectl get all -n monitoring
```

### Expose Grafana via Ingress

Create a Grafana ingress manifest with:

- Path: /grafana
- TLS configuration
- NGINX ingress class

Configure Grafana for subpath routing:

```bash
kubectl set env deployment/grafana -n monitoring \
  GF_SERVER_ROOT_URL="https://pwc-pythontask.northeurope.cloudapp.azure.com/grafana" \
  GF_SERVER_SERVE_FROM_SUB_PATH="true"
```

### Retrieve Grafana Credentials

```bash
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
echo
```


### Access Grafana

- URL: https://pwc-pythontask.northeurope.cloudapp.azure.com/grafana
- Username: admin
- Password: (from previous command)

<img width="1711" height="868" alt="image" src="https://github.com/user-attachments/assets/10b7a345-bc04-4949-b550-39a9102afa9e" />

> [!Note]
>  when you access now grafana under connections click on data sources you will see loki and Prometheus already configred.
<img width="1915" height="602" alt="image" src="https://github.com/user-attachments/assets/5a4a5d83-f5c7-4d00-8128-39342ef6d752" />


### Import Pre-built Dashboards

Import the following dashboards in Grafana:

**Kubernetes Cluster Monitoring:**

- Dashboard → New → Import
- Dashboard ID: 15757
- Select Prometheus datasource

**Loki Logs Dashboard:**

- Dashboard → New → Import
- Dashboard ID: 13639
- Select Loki datasource

**Pod Logs Dashboard:**

- Dashboard → New → Import
- Dashboard ID: 15141
- Select Prometheus datasource

### Logs for the App
<img width="1893" height="723" alt="image" src="https://github.com/user-attachments/assets/a26832e9-25ac-45d5-bca9-90f516b4bc04" />

### k8s Cluster metrics utlization
<img width="1897" height="862" alt="image" src="https://github.com/user-attachments/assets/3e8a84e0-7292-445c-9308-5220df6f4f04" />


## Key Features

- Automated infrastructure provisioning with Terraform
- Secure container registry integration
- GitOps-based continuous deployment
- Automated SSL certificate management
- Horizontal pod autoscaling capability
- Comprehensive monitoring and logging
- Centralized log aggregation
- Real-time metrics visualization

## Security Considerations

- ACR credentials stored as GitHub secrets
- TLS encryption for all external traffic
- Private container registry access via role assignments
- Network policies enabled on AKS cluster
- Automated certificate renewal with cert-manager

## Scaling

The AKS cluster is configured with auto-scaling:

- Minimum nodes: 1
- Maximum nodes: 5
- Default node count: 1

Deployments can be scaled manually:

```bash
kubectl scale deployment python-microservice -n microservice --replicas=3
```

## Conclusion
This project demonstrates a production-ready microservice deployment leveraging modern DevOps practices and cloud-native technologies. By combining Infrastructure as Code with Terraform, GitOps with ArgoCD, and automated CI/CD pipelines, we achieve a fully automated deployment workflow that minimizes manual intervention and reduces the risk of human error.
The implementation showcases key principles of cloud-native architecture including containerization, orchestration, automated scaling, secure networking, and comprehensive observability. The monitoring stack with Prometheus, Loki, and Grafana provides complete visibility into application performance and system health, enabling proactive issue detection and resolution.
This architecture is scalable, maintainable, and follows industry best practices for security and reliability. The GitOps approach ensures that infrastructure and application state are version-controlled and auditable, while the automated CI/CD pipeline enables rapid and consistent deployments.
