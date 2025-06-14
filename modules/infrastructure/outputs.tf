output "nodes" {
  description = "List of node details"
  value = [
    for idx, instance in google_compute_instance.clickhouse_node : {
      name        = local.node_names[idx]
      instance_id = instance.id
      internal_ip = instance.network_interface[0].network_ip
      external_ip = instance.network_interface[0].access_config[0].nat_ip
      ssh_user    = "ubuntu"
      index       = idx + 1
    }
  ]
}

output "network" {
  description = "VPC network details"
  value = {
    id   = google_compute_network.vpc_network.id
    name = google_compute_network.vpc_network.name
  }
}

output "subnet" {
  description = "Subnet details"
  value = {
    id   = google_compute_subnetwork.vpc_subnet.id
    name = google_compute_subnetwork.vpc_subnet.name
    cidr = google_compute_subnetwork.vpc_subnet.ip_cidr_range
  }
}