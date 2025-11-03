variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-microservice"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "North Europe"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-microservice-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33.3"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_D2s_v3"
}
