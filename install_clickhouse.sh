#!/bin/bash
# Install prerequisite packages

sudo service clickhouse-server stop
sudo apt-get remove -y clickhouse-server clickhouse-keeper clickhouse-client 
sudo killall -9 clickhouse*
sleep 10
sudo rm -rf /var/lib/clickhouse

sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
# Download the ClickHouse GPG key and store it in the keyring
curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | sudo gpg --yes --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg

# Get the system architecture
ARCH=$(dpkg --print-architecture)

# Add the ClickHouse repository to apt sources
echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg arch=${ARCH}] https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list

# Update apt package lists
sudo apt-get update

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y clickhouse-server clickhouse-client

sudo service clickhouse-server start


clickhouse-client --query "CREATE DATABASE IF NOT EXISTS dev;"

