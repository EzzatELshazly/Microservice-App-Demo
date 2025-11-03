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

## Project Structure

```
.
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── namespace.yaml
│   └── grafana-ingress.yaml
├── .github/
│   └── workflows/
│       └── ci-cd.yaml
├── Dockerfile
├── requirements.txt
└── run.py
```

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

### Important: Terraform Initialization Order

Due to the remote backend dependency, follow this specific initialization sequence:

1. Temporarily comment out the `backend "azurerm"` block in provider.tf
2. Initialize and apply Terraform:

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

3. After resources are created, uncomment the backend block
4. Reinitialize with state migration:

```bash
terraform init -migrate-state
```

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
- TLS termination with Let's Encrypt
- Force SSL redirect
- Domain routing

## Phase 4: GitOps with ArgoCD

### Install ArgoCD

Create ArgoCD namespace and install:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

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
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

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
2. Go to Configuration section
3. Create a DNS name label (e.g., pwc-pythontask)
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

The application is now accessible via HTTPS.

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

**Update Manifest Job:**

- Checks out code with write permissions
- Updates deployment.yaml with new image tag
- Commits and pushes changes to trigger ArgoCD sync

### Workflow Triggers

The pipeline runs automatically on push to the main branch.

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

## Deployment Workflow

1. Developer pushes code to main branch
2. GitHub Actions builds Docker image and pushes to ACR
3. GitHub Actions updates Kubernetes manifest with new image tag
4. ArgoCD detects manifest change and syncs deployment
5. New pods are deployed to AKS cluster
6. NGINX Ingress routes traffic to new pods
7. Metrics and logs are collected by Prometheus and Loki
8. Grafana displays monitoring data and logs

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
- Kubernetes RBAC for access control
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

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n microservice
kubectl describe pod <pod-name> -n microservice
kubectl logs <pod-name> -n microservice
```

### Check Ingress

```bash
kubectl get ingress -n microservice
kubectl describe ingress python-microservice-ingress -n microservice
```

### Check Certificate

```bash
kubectl get certificate -n microservice
kubectl describe certificate pwc-python-cert -n microservice
```

### Check ArgoCD Application

```bash
argocd app get <app-name>
argocd app sync <app-name>
```

## Cleanup

To destroy all resources:

```bash
cd terraform/
terraform destroy
```

Note: Manually delete the DNS configuration from Azure Portal if created.

## License

This project is for demonstration purposes.

## Author

PWC Microservice Demonstration Project
