variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "region" {
  description = "The region to deploy resources"
  type        = string
}

variable "zone" {
  description = "The zone to deploy resources"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the instances"
  type        = string
}

variable "disk_size_gb" {
  description = "Size of the boot disk in GB"
  type        = string
}

variable "node_count" {
  description = "Number of nodes to create"
  type        = number
  default     = 3
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "private_key_path" {
  description = "Path to the private SSH key file"
  type        = string
}