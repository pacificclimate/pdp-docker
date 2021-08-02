#!/bin/bash
# This script creates a user on the host that a Docker container maps to with user
# namespace remapping enabled.

host_groupname=${1:-dockeragent1000}
host_userns_username=${1:-dockeragent}
container_uid=${2:-1000}
host_username_prefix=${3:-"$host_userns_username"}

host_uid_base=$(egrep "^$host_userns_username" /etc/subuid | cut -d ':' -f 2)
host_uid=$(( host_uid_base + container_uid ))

host_username="${host_username_prefix}${container_uid}"

#sudo useradd -g "$host_uid" "$host_username"
echo "user=$host_username($host_uid) group=$host_groupname"