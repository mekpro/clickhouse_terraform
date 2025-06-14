# ClickHouse Cluster with Replication using ClickHouse Keeper

This Terraform project sets up a ClickHouse cluster with 3 nodes in Google Cloud Platform:
- 2 nodes running both ClickHouse data server and ClickHouse Keeper
- 1 node running only ClickHouse Keeper for quorum (no data)

## Prerequisites

- Google Cloud Platform account with a project
- Terraform installed locally
- Google Cloud SDK installed
- SSH key pair
- Change default password in modules/clickhouse/user_admin.xml with ( echo -n 'your_new_strong_password' | sha256sum | tr -d ' -' )
 
## Configuration

1. Set up your Google Cloud credentials:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.googlecloud.json"
```

2. Update the private key path in the `terraform.tfvars` file:

```hcl
private_key_path = "~/.ssh/id_ed25519"  # Path to your private SSH key
```

## Deployment

To deploy the ClickHouse cluster:

1. Navigate to the dev environment:

```bash
cd environments/dev
```

2. Initialize Terraform:

```bash
terraform init
```

3. Apply the Terraform plan:

```bash
terraform apply
```

4. After deployment completes (approx. 5-10 minutes), you'll get outputs with the ClickHouse endpoints:

```
clickhouse_endpoints = {
  "chnode1" = "x.x.x.x:8123"
  "chnode2" = "y.y.y.y:8123"
  "chnode3" = "z.z.z.z:8123"
}

clickhouse_clients = {
  "chnode1" = "x.x.x.x:9000"
  "chnode2" = "y.y.y.y:9000"
  "chnode3" = "z.z.z.z:9000"
}
```

## Testing the Deployment

You can connect to your ClickHouse cluster using the clickhouse-client:

```bash
clickhouse-client --host=x.x.x.x --port=9000
```

Or via HTTP:

```bash
curl "http://x.x.x.x:8123/?query=SELECT%20*%20FROM%20db1.table1_dist"
```

## Architecture

The cluster is configured with:
- 2 shards (one on each data node)
- 1 replica per shard
- A distributed table to query data across all shards

### Configuration Files

Each node has the following configuration files:

1. `network-and-logging.xml` - Basic network and logging configuration
2. `enable-keeper.xml` - ClickHouse Keeper configuration with server ID
3. `macros.xml` - Defines shard and replica macros (data nodes only)
4. `remote-servers.xml` - Cluster configuration
5. `use-keeper.xml` - Configuration to use ClickHouse Keeper for coordination

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```
