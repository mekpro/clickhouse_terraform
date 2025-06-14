variable "nodes" {
  description = "List of node details"
  type = list(object({
    name        = string
    instance_id = string
    internal_ip = string
    external_ip = string
    ssh_user    = string
    index       = number
  }))
}

variable "private_key_path" {
  description = "Path to the private SSH key file"
  type        = string
}