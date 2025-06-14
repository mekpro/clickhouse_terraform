#!/bin/bash

# Clear existing custom entries from /etc/hosts
# Keep the localhost entries
sed -i '/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}.*chnode/d' /etc/hosts

# Add all nodes to /etc/hosts
%{ for node in nodes ~}
echo "${node.internal_ip} ${node.name}" >> /etc/hosts
%{ endfor ~}

# Show the updated hosts file
echo "Updated /etc/hosts:"
cat /etc/hosts