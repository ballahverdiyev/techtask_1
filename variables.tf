variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type    = string
  default = "demo-eks-karpenter"
}

# Set this to the latest EKS-supported Kubernetes minor version before apply.
variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}
variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
}
 
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"]
}
variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}