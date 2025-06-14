resource "null_resource" "setup_clickhouse_keeper" {
  count = length(var.nodes)
  
  connection {
    type        = "ssh"
    user        = var.nodes[count.index].ssh_user
    private_key = file(var.private_key_path)
    host        = var.nodes[count.index].external_ip
    timeout     = "5m"
    agent       = false
  }
  
  # Create directory structure
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/clickhouse/coordination/log",
      "sudo mkdir -p /var/lib/clickhouse/coordination/snapshots",
      "sudo chown -R clickhouse:clickhouse /var/lib/clickhouse/coordination"
    ]
  }
  
  # Copy network and logging configuration
  provisioner "file" {
    content     = file("${path.module}/network-and-logging.xml.tpl")
    destination = "/tmp/network-and-logging.xml"
  }
  
  # Configure ClickHouse Keeper
  provisioner "file" {
    content     = templatefile("${path.module}/enable-keeper.xml.tpl", {
      server_id = var.nodes[count.index].index
    })
    destination = "/tmp/enable-keeper.xml"
  }
  
  # Configure macros (only for the data nodes, not for the keeper-only node)
  provisioner "file" {
    content     = templatefile("${path.module}/macros.xml.tpl", {
      shard = count.index < 2 ? var.nodes[count.index].index : "none"
    })
    destination = "/tmp/macros.xml"
  }
  
  # Configure remote servers
  provisioner "file" {
    content     = file("${path.module}/remote-servers.xml.tpl")
    destination = "/tmp/remote-servers.xml"
  }
  
  # Configure use of Keeper
  provisioner "file" {
    content     = file("${path.module}/use-keeper.xml.tpl")
    destination = "/tmp/use-keeper.xml"
  }
  
  # Move configuration files to their proper location and start/restart services
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/network-and-logging.xml /etc/clickhouse-server/config.d/",
      "sudo mv /tmp/enable-keeper.xml /etc/clickhouse-server/config.d/",
      "sudo mv /tmp/macros.xml /etc/clickhouse-server/config.d/",
      "sudo mv /tmp/remote-servers.xml /etc/clickhouse-server/config.d/",
      "sudo mv /tmp/use-keeper.xml /etc/clickhouse-server/config.d/",
      "sudo chown -R clickhouse:clickhouse /etc/clickhouse-server/config.d/",
      "sudo service clickhouse-server stop || true",
      "sudo service clickhouse-server start",
      "echo 'Waiting for ClickHouse Server and Keeper to fully initialize...'",
      "sleep 30"
    ]
  }
  
  # Verify Keeper is working properly
  provisioner "remote-exec" {
    inline = [
      "echo 'Verifying ClickHouse Keeper status...'",
      "attempt=1",
      "max_attempts=10",
      "while [ $attempt -le $max_attempts ]; do",
      "  echo \"Attempt $attempt/$max_attempts to verify ClickHouse Keeper...\"",
      "  if clickhouse-client --query \"SELECT * FROM system.zookeeper WHERE path = '/'\" --format TabSeparated 2>/dev/null; then",
      "    echo 'ClickHouse Keeper is operational'",
      "    break",
      "  else",
      "    echo 'ClickHouse Keeper not ready yet, waiting...'",
      "    if [ $attempt -eq $max_attempts ]; then",
      "      echo 'Warning: Maximum attempts reached, continuing anyway...'",
      "    else",
      "      sleep 30",
      "    fi",
      "  fi",
      "  attempt=$((attempt+1))",
      "done"
    ]
  }
}