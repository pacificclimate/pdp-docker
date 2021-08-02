#!/bin/bash
# This script creates a group on the host that a Docker container maps to with user
# namespace remapping enabled.

host_userns_groupname=dockeragent
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