resource "null_resource" "setup_clickhouse_replication" {
  # We only need to run this on the first node
  
  connection {
    type        = "ssh"
    user        = var.nodes[0].ssh_user
    private_key = file(var.private_key_path)
    host        = var.nodes[0].external_ip
    timeout     = "5m"
    agent       = false
  }
  
  # Initial wait for ClickHouse to start
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for ClickHouse to start...'",
      "sleep 30"
    ]
  }
  
  # Check if ClickHouse is running
  provisioner "remote-exec" {
    inline = [
      "echo 'Checking if ClickHouse is running...'",
      "for i in $(seq 1 10)",
      "do",
      "  if clickhouse-client --query 'SELECT 1' 2>/dev/null",
      "  then",
      "    echo 'ClickHouse is operational'",
      "    break",
      "  else",
      "    echo \"Attempt $i: ClickHouse not ready yet, waiting...\"",
      "    if [ $i -eq 10 ]",
      "    then",
      "      echo 'ERROR: ClickHouse failed to start after maximum attempts'",
      "      exit 1",
      "    fi",
      "    sleep 15",
      "  fi",
      "done"
    ]
  }
  
  # Check ClickHouse Keeper connectivity
  provisioner "remote-exec" {
    inline = [
      "echo 'Verifying ClickHouse Keeper connectivity...'",
      "for i in $(seq 1 10)",
      "do",
      "  if clickhouse-client --query \"SELECT * FROM system.zookeeper WHERE path = '/'\" --format TabSeparated 2>/dev/null",
      "  then",
      "    echo 'ClickHouse Keeper is operational'",
      "    break",
      "  else",
      "    echo \"Attempt $i: ClickHouse Keeper not ready yet, waiting...\"",
      "    if [ $i -eq 10 ]",
      "    then",
      "      echo 'ERROR: ClickHouse Keeper failed to start after maximum attempts'",
      "      exit 1",
      "    fi",
      "    sleep 15",
      "  fi",
      "done"
    ]
  }
  
  # Copy the SQL script
  provisioner "file" {
    source      = "${path.module}/setup_tables.sql"
    destination = "/tmp/setup_tables.sql"
  }
  
  # Run the SQL script with retry
  provisioner "remote-exec" {
    inline = [
      "echo 'Running SQL setup script...'",
      "for i in $(seq 1 5)",
      "do",
      "  if clickhouse-client --multiquery < /tmp/setup_tables.sql 2>/dev/null",
      "  then",
      "    echo 'SQL setup completed successfully'",
      "    break",
      "  else",
      "    echo \"Attempt $i: SQL setup failed, retrying...\"",
      "    if [ $i -eq 5 ]",
      "    then",
      "      echo 'WARNING: SQL setup failed after maximum attempts, continuing anyway'",
      "    fi",
      "    sleep 15",
      "  fi",
      "done"
    ]
  }
  
  # Test insert on second node
  provisioner "remote-exec" {
    inline = [
      "echo 'Testing insert on node 2...'",
      "sleep 10",
      "for i in $(seq 1 5)",
      "do",
      "  echo \"Attempt $i: Inserting data on node 2...\"",
      "  if ssh -o StrictHostKeyChecking=no ${var.nodes[1].ssh_user}@${var.nodes[1].internal_ip} \"clickhouse-client --query \\\"INSERT INTO db1.table1 VALUES (2, 'test data from node 2')\\\"\" 2>/dev/null",
      "  then",
      "    echo 'Insert on node 2 succeeded'",
      "    break",
      "  else",
      "    echo \"Insert on node 2 failed, retrying...\"",
      "    if [ $i -eq 5 ]",
      "    then",
      "      echo 'WARNING: Insert on node 2 failed after maximum attempts, continuing anyway'",
      "    fi",
      "    sleep 15",
      "  fi",
      "done"
    ]
  }
  
  # Test distributed query
  provisioner "remote-exec" {
    inline = [
      "echo 'Testing distributed table query...'",
      "for i in $(seq 1 5)",
      "do",
      "  echo \"Attempt $i to query distributed table...\"",
      "  if clickhouse-client --query 'SELECT * FROM db1.table1_dist' 2>/dev/null",
      "  then",
      "    echo 'Distributed query succeeded'",
      "    break",
      "  else",
      "    echo \"Distributed query failed, retrying...\"",
      "    if [ $i -eq 5 ]",
      "    then",
      "      echo 'WARNING: Distributed query failed after maximum attempts'",
      "    fi",
      "    sleep 15",
      "  fi",
      "done",
      "echo 'ClickHouse cluster with replication setup completed!'"
    ]
  }
}