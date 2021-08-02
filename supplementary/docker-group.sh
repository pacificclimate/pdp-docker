#!/bin/bash
# This script creates a group on the host that a Docker container maps to with user
# namespace remapping enabled.

host_userns_groupname=${1:-dockeragent}
container_gid=${2:-1000}
host_groupname_prefix=${3:-"$host_userns_groupname"}

host_gid_base=$(egrep "^$host_userns_groupname" /etc/subgid | cut -d ':' -f 2)
host_gid=$(( host_gid_base + container_gid ))

host_groupname="${host_groupname_prefix}${container_gid}"

#sudo groupadd -g "$host_gid" "$host_groupname"
echo "group=$host_groupname($host_gid)"