#!/bin/bash
# This script creates a group on the host that a Docker container maps to with user
# namespace remapping enabled.
#
# Options
#
#   -n host_userns_groupname : The name of the host group specified for the Docker
#     daemon param userns-remap (specified in /etc/docker/daemon.json). Default: dockremap
#
#   -i container_gid : The id of the container group of the container user. Default: 1000
#
#   -p host_groupname_prefix : A prefix with which the host group created by this script
#     is formed. (The host group name is "${host_groupname_prefix}${container_gid}".)
#     Default: dockremap

host_userns_groupname=dockremap
container_gid=1000
host_groupname_prefix="$host_userns_groupname"

while getopts "n:i:p:" flag
do
  case "$flag" in
    n) host_userns_groupname="$OPTARG";;
    i) container_gid="$OPTARG";;
    p) host_groupname_prefix="$OPTARG";;
    *) printf "gronk"
       exit 1;;
  esac
done

host_gid_base=$(egrep "^$host_userns_groupname" /etc/subgid | cut -d ':' -f 2)
if [ -z "$host_gid_base" ]; then
  echo "User '$host_userns_groupname' (option -n) not found in /etc/subgid."
  exit 1
fi

host_gid=$(( host_gid_base + container_gid ))

host_groupname="${host_groupname_prefix}${container_gid}"

#sudo groupadd -g "$host_gid" "$host_groupname"
echo "added host group $host_gid($host_groupname)"