#!/bin/bash
# This script creates a user on the host that a Docker container maps to with user
# namespace remapping enabled.
#
# Options
#   
#   -g host_groupname : The name of the host group to which the newly created user
#     is added.
#
#   -n host_userns_username : The name of the host user specified for the Docker
#     daemon param userns-remap (specified in /etc/docker/daemon.json). 
#
#   -i container_gid : The id of the container user of the container user.
#
#   -p host_username_prefix : A prefix with which the host user created by this script 
#     is formed. (The host user name is "${host_username_prefix}${container_gid}".)

host_userns_username=dockremap
container_uid=1000
host_username_prefix="$host_userns_username"
host_groupname="${host_userns_username}${container_uid}"

while getopts "g:n:i:p:" flag
do
  case "$flag" in
    g) host_groupname="$OPTARG";;
    n) host_userns_username="$OPTARG";;
    i) container_uid="$OPTARG";;
    p) host_username_prefix="$OPTARG";;
    *) printf "gronk"
       exit 1;;
  esac
done

if [ ! $(getent group $host_groupname) ]; then
  echo "Host group '$host_groupname' (option -g) does not exist."
  exit 1
fi

host_uid_base=$(egrep "^$host_userns_username" /etc/subuid | cut -d ':' -f 2)
if [ -z "$hostuid_base" ]; then
  echo "User '$host_userns_username' (option -n) not found in /etc/subuid."
  exit 1
fi

host_uid=$(( host_uid_base + container_uid ))

host_username="${host_username_prefix}${container_uid}"

sudo useradd -r -g "$host_groupname" -u "$host_uid" "$host_username"
echo "added host user $host_uid($host_username) to group $host_groupname"
id "$host_username"
