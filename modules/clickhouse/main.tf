resource "null_resource" "install_clickhouse" {
  triggers = { version = "1.0.1" } 
  count = length(var.nodes)
  
  connection {
    type        = "ssh"
    user        = var.nodes[count.index].ssh_user
    private_key = file(var.private_key_path)
    host        = var.nodes[count.index].external_ip
    timeout     = "5m"
    agent       = false
  }

  # First check SSH connectivity
  provisioner "remote-exec" {
    inline = [
      "echo 'Testing SSH connectivity before ClickHouse installation'"
    ]
  }
  
  # Copy the installation script
  provisioner "file" {
    source      = "${path.module}/install_clickhouse.sh"
    destination = "/tmp/install_clickhouse.sh"
  }

  # Execute the installation script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_clickhouse.sh",
      "/tmp/install_clickhouse.sh"
    ]
  }
  
  # Create directory for configuration files
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/clickhouse-server/config.d/",
      "sudo chmod 755 /etc/clickhouse-server/config.d/"
    ]
  }
  
  # Copy user_admin.xml configuration file
  provisioner "file" {
    source      = "${path.module}/user_admin.xml"
    destination = "/tmp/user_admin.xml"
  }
  
  # Move the file to the ClickHouse configuration directory
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/user_admin.xml /etc/clickhouse-server/users.d/",
      "sudo chown clickhouse:clickhouse /etc/clickhouse-server/users.d/user_admin.xml",
      "sudo chmod 644 /etc/clickhouse-server/users.d/user_admin.xml",
      "sudo systemctl restart clickhouse-server"
    ]
  }
}