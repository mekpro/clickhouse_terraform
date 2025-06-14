locals {
  node_names = [for i in range(var.node_count) : "chnode${i + 1}"]
}

# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "vpc_subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

# Firewall rules for SSH access
resource "google_compute_firewall" "iap_ssh" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP's IP range
  target_tags   = ["ssh"]
}

# Allow direct SSH for terraform provisioners
resource "google_compute_firewall" "ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # Allow from anywhere - restrict this in production
  target_tags   = ["ssh"]
}

# Firewall rule for clickhouse access
resource "google_compute_firewall" "clickhouse" {
  name    = "${var.network_name}-allow-clickhouse"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8123", "9000", "9181", "9234", "9009"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["clickhouse"]
}

# Internal communication between clickhouse nodes
resource "google_compute_firewall" "internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["clickhouse"]
}

# Compute instance for each node
resource "google_compute_instance" "clickhouse_node" {
  count        = var.node_count
  name         = "${local.node_names[count.index]}-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone
  
  tags = ["clickhouse", "ssh"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = var.disk_size_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.vpc_subnet.id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # Enable IAP access
  service_account {
    scopes = ["cloud-platform"]
  }

  # Just set the hostname, we'll set up /etc/hosts separately
  metadata_startup_script = <<-EOF
    #!/bin/bash
    # Set hostname
    hostnamectl set-hostname ${local.node_names[count.index]}
  EOF

  allow_stopping_for_update = true
  
  # Make sure SSH is up and running
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
      timeout     = "5m"
      agent       = false
    }
    
    # Just a simple command to test SSH access
    inline = ["echo 'SSH connection successful'"]
  }
}

# Configure /etc/hosts across all nodes after they're created
resource "null_resource" "configure_hosts" {
  depends_on = [google_compute_instance.clickhouse_node]
  
  # We need to make sure this runs after all nodes are created and have their IPs assigned
  triggers = {
    instance_ids = join(",", [for instance in google_compute_instance.clickhouse_node : instance.id])
  }
  
  # Run on each node
  count = var.node_count
  
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = google_compute_instance.clickhouse_node[count.index].network_interface[0].access_config[0].nat_ip
    timeout     = "5m"
    agent       = false
  }

  # Create the hosts file configuration script
  provisioner "file" {
    content = templatefile("${path.module}/configure_hosts.sh.tpl", {
      nodes = [
        for idx, instance in google_compute_instance.clickhouse_node : {
          name        = local.node_names[idx]
          internal_ip = instance.network_interface[0].network_ip
        }
      ]
    })
    destination = "/tmp/configure_hosts.sh"
  }
  
  # Run the hosts file configuration script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/configure_hosts.sh",
      "sudo /tmp/configure_hosts.sh"
    ]
  }
}