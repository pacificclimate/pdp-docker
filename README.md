# PDP Docker base images

This repo defines some common base images used in the PDP project. 

The PDP project, namely repos `pdp` and `pdp_util`, build several distinct but 
very similar execution environments:

- Production image
- CI testing (GitHub workflows, etc.)
- Running tests and full app during development (on workstation)

To simplify keeping these various environments consistent,
we define two base images in this repo. These images 

- do not create a full PDP environment, but instead install the unchanging or 
slow-changing basics common to all such environments;
- can be run directly or used as base images for more complete 
environments, depending on need. 

Repos `pdp` and `pdp_util`  are responsible for defining and building 
complete environments for the various purposes. See [Usage](#usage) below.

## Images

| Image name | Dockerfile | Base image | Notes (see below) |
|---|---|---|---|
| pcic/pdp-base-minimal | base-minimal.Dockerfile | ubuntu:18.04 | Safe |
| pcic/pdp-base-minimal-unsafe | base-minimal.Dockerfile | ubuntu:18.04 | UNSAFE |
| pcic/pdp-base-with-pg9.5 | base-with-pg9.5.Dockerfile | pcic/pdp-base-minimal | Safe |
| pcic/pdp-base-with-pg9.5-unsafe | base-with-pg9.5.Dockerfile | pcic/pdp-base-minimal-unsafe | UNSAFE |

Notes:

- Safe: This image sets a non-root user and is safe to run on
  hosts with access to sensitive infrastructure.
- UNSAFE: This image uses the root user throughout, does not set a non-root
  user and is **not safe to run on hosts with access to sensitive 
  infrastructure**. Do not run this image on a workstation, 
  on a self-hosted GitHub runner, or on a server behind the PCIC firewall.
  (This image is used only for running CI on a GitHub-hosted runner.)
  
### Build args and environment variables

To support a (typically) non-root user, the following build args are defined
in `base-minimal.Dockerfile`:

- `USERNAME`: Name of user. Default: `dockremap`.
- `UID`: Numerical id of user. Default: `1000`.
- `GROUPNAME`: Name of user's group. Default: `<USERNAME>`.
- `GID`: Numerical id of group. Default: `1000`.
- `USER_DIR`: Home directory of user. Default: `/opt/<USERNAME>`.

These build args can be overridden to define a different user, including as
`root`, which yields an UNSAFE image (see above).

These build args are passed into environment variables of the same names
for convenient use by subsequent images or containers.

### `pcic/pdp-base-minimal`

- Base image: `ubuntu:18.04`.
- Installs all Ubuntu packages needed for running the PDP and the
  tests in repo `pdp`.
- Installs a small set of fundamental Python packages needed by PDP.
  (Remaining packages must be installed by the image or container 
  responsible for building a full PDP environment.)
- Defines a non-root user and group and switches to it to install the 
  Python packages. Built with `USERNAME=dockremap`.
- Safe (see above): 
  For security, the non-root user remains the active user at the end of 
  image build. If higher privilege is needed while building an image based
  on this one, the image should do the following:
  
  ```
  USER root
  
  # Perform operations with root privilege
  ...
  
  # Return to non-privileged user
  USER ${USERNAME}
  ```
  
### `pcic/pdp-base-minimal-unsafe`

Like `pcic/pdp-base-minimal`, except:

- UNSAFE (see above): Does NOT define a non-root user and group; instead
  is built with `USERNAME=root`. 
  **Do not run on hosts with access to sensitive infrastructure.** 
  
### `pcic/pdp-base-with-pg9.5`

- Base image: `pcic/pdp-base-minimal`.
- Installs Ubuntu packages necessary to support PostgreSQL 9.5. (These packages
  require using a special legacy library available only for Ubuntu 18.04 or
  earlier.)
- Safe (see above): 
  For security, the non-root user remains the active user at the end of 
  image build. (For details, see section `pcic/pdp-base-minimal` above.)

### `pcic/pdp-base-with-pg9.5-unsafe`

Like `pcic/pdp-base-with-pg9.5`, except:

- Base image: `pcic/pdp-base-minimal-unsafe`.
- UNSAFE (see above):  
  **Do not run on hosts with access to sensitive infrastructure.** 
  
## Usage

### Production

The base for the production Docker image (defined in `pdp`) is 
`pcic/pdp-base-minimal`.
It installs the remaining Python dependencies to create a production
build of the PDP.

### CI tests

- `pdp`: At present, repo `pdp` does not need a PostgreSQL server to run its 
  tests. It therefore runs the simpler image `pcic/pdp-base-minimal`.
- `pdp_util`: At present, repo `pdp_util` requires a PostgreSQL server to run 
  its tests. It therefore runs the image `pcic/pdp-base-with-pg9.5`.
  
Both test containers install the remaining Python dependencies and run the 
respective tests.

### Running tests and PDP application on workstation

It is difficult on an up-to-date workstation to install a 
suitable environment for running the PDP's tests or the application.

Instead, we can use a Docker container. The images in this repo provide 
suitable bases for these builds.

Since both `pdp` and `pdp_util` need to do this, we present the explanation
of how these containers work in one place, namely here. The actual images and
containers are defined and built in their respective repos.

#### Mechanism

1. The development image is built with all the contents necessary to install 
   and run the package and its tests. 

1. Since we want to run locally modified code, we can't install the 
   codebase from a repo (as we do for building a production image or running 
   CI tests). Instead we mount the local workstation codebase to the 
   container and install from that when the container is started.

1. To facilitate this, the development image sets up a working directory
   (`WORKDIR`) called `/codebase`. 

1. When we run the image, we mount the local codebase to `/codebase`.

1. When the container starts (image runs), it invokes an entrypoint script 
   that installs the local version of this project (in development mode `-e`)
   from `/codebase`.

1. Because we mounted our codebase to the container, when we make changes to 
   it (outside the container), those changes are available inside the 
   container. Therefore we can use all our workstation tools outside the 
   container as normal (which is far easier than trying to install your IDE 
   inside the container :) ).

1. Installing the local codebase (`pip install -e .`) requires writing to the 
   same directory it is found in. Thus we have to mount our local codebase 
   read-write. This also makes it possible to write other files inside the 
   container that are conveniently visible outside (e.g., redirected test 
   output). The disadvantage of mounting the codebase read-write is that test 
   runs leave behind a set "orphaned" pytest caches which will cause the next 
   run of the image to fail if they are not cleaned up first with `py3clean`.

#### Procedure for development images

This section outlines the procedure used to set up and use a development image.
Individual development images in each repo may have slightly different
procedures.

1. (Once per host environment) Prepare the host environment for Docker user
   namespace remapping. 
   This is only necessary if you want to run a development image with 
   write privileges to a mounted filesystem.
   
   Follow the 
   [Setting up Docker namespace remapping (with recommended parameters)](#setting-up-docker-namespace-remapping-with-recommended-parameters) 
   immediately below. 
  
1. (Initially; infrequently thereafter) Pull or locally build the Docker 
   image that creates the development environment.

1. (When you wish to run tests or run the application) Run the image, mounting
   the local codebase. Inside the container, run the tests or start the
   application. Running the image and/or running the tests or starting the
   application may be automated by docker-compose and/or by scripts provided
   in the project.
   
#### Setting up Docker namespace remapping (with recommended parameters)

Docker namespace remapping can be customized in several ways, but we
do not need such customizations for our purposes here. These instructions
therefore shorter and simpler as they use recommended or default values
for all customization parameters.

1. Create or edit `/etc/docker/daemon.json` to include the parameter 
   `userns-remap` with recommended value `default`:
   
   ```
   {
     "userns-remap": "default"
   }
   ``` 
   
   With the value `default` for this parameter, Docker will automatically
   create a user and group named `dockremap`, and add required entries to
   `/etc/subuid` and `/etc/subgid`.

1. Restart Docker:
   ```
   sudo systemctl restart docker
   ```
   
   and check that it is running again: 
    
   ```  
   sudo systemctl status docker
   ```  

1. Verify that Docker created the expected user, group, and entries in 
   `/etc/subuid` and `/etc/subgid`:
   
   ```
   $ id dockremap 
   uid=130(dockremap) gid=135(dockremap) groups=135(dockremap),1000(rglover)
   ```
   
   ```
   $ grep dockremap /etc/subuid
   dockremap:165536:65536
   ```
   
   ```
   $ grep dockremap /etc/subgid
   dockremap:165536:65536
   ```
   
1. Create a host group and user to which the container user and group
   will be mapped.
   
   This repository contains two scripts that do most of the work of 
   creating such groups and users on the host. (Each script takes
   arguments that specify values such as the name of the Docker user
   created in the previous steps. However, these arguments all default
   to the recommended values, so we do not need to specify them.)
   
   Note that the group must be created before the user.
   
   1. Run 
      
      ```
      ./supplementary/docker-group.sh
      ```
      
      This creates a group named `dockremap1000`.
      
   1. Run 
      
      ```
      ./supplementary/docker-user.sh
      ```
      
      This creates a user named `dockremap1000`.
      
   1. Verify user and group created:
   
   ```
   $ id dockremap1000
   uid=166536(dockremap1000) gid=166536(dockremap1000) groups=166536(dockremap1000)
   ```
   
   There should be entries very like this for each item listed 
   (`uid`, `gid`, `groups`).
   
1. Give the host group (or user if you wish) appropriate privileges on the 
    directories you plan to mount. 
   
    It is probably easiest to use ACL for this:
    
    ```
    setfacl -m "g:dockremap1000:rwx" <directory>
    ```
    
    gives any member of the group `dockremap1000` read, write, and execute
    privileges on the specified directory.

#### Setting up Docker namespace remapping (with custom parameters)

It seems unlikely that we will need to set up namespace remapping with
anything other than the recommended parameters (procedure above). However,
if for some reason it is necessary, here is the procedure.

1. Decide what user and group you wish to use on the host as the Docker
   remap user. It is probably best to create a new, single-purpose user 
   for this. 
   
1. Add entries to `/etc/subuid` and `/etc/subgid` for the Docker remap user 
   and group. For details on this, see Docker documentation
   [Isolate containers with a user namespace](https://docs.docker.com/engine/security/userns-remap/), 
   section Prerequisites.

1. Decide the numerical user and group id for the user and group that are
   to be defined in the image (which will be the active user in any
   container run from the image). 
   
   Also decide the names of the user and group. These are arbitrary
   and have no effect or appearance anywhere outside the image/container.
      
1. The Docker images defined in this repo accept build arguments for the
   user name, user id, group name, and group id. For more information,
   see [Build args and environment variables](#build-args-and-environment-variables).
   
   Build a new image with build arguments specified accordingly.
   
   The resulting Docker image runs with a non-privileged user with the
   specified user and group ids.

1. Create a host group and user to which the image/container user and
   group will be mapped when run. Note that the group must be created
   before the user.

   1. Choose a prefix for the name of the host group to be created.
      The resulting name is the prefix followed by the group id.
      
   1. Run 
      
      ```
      ./supplementary/docker-group.sh -p prefix -i container_gid -n host_userns_groupname
      ```
      
      where 
      
      - `prefix` is the prefix you chose,
      - `container_gid` is the numerical id of the group in the image 
        as specified in the build args, and
      - `host_userns_groupname` is the name of the group specified in 
        `userns-remap`
      
      This creates a named group on your host machine corresponding to 
      (i.e., mapped from) the group used in the container(s).
   
   1. Choose a prefix for the name of the host user to be created.
      The resulting name is the prefix followed by the user id.
   
   1. Run 
      
      ```
      ./supplementary/docker-user.sh -p prefix -i container_uid -n host_userns_username -g host_groupname 
      ```
      
      where 
      
      - `prefix` is the prefix you chose,
      - `container_uid` is the numerical id of the user in the image 
        as specified in the build args, and
      - `host_userns_username` is the name of the user specified in 
      `userns-remap`
      - `host_groupname` is the name of the group you created in the
        previous step,
      
      This creates a named user on your host machine corresponding to 
      (i.e., mapped from) the user used in the container(s).
      
   1. Verify user and group created:
   
   ```
   $ id <username>
   ```
   
   where `<username>` is the name of the user as displayed by the
   `docker-user.sh` script.

1. Give the host group (or user if you wish) appropriate privileges on the 
    directories you plan to mount. 
   
    It is probably easiest to use ACL for this:
    
    ```
    setfacl -m "g:<groupname>:rwx" <directory>
    ```
    
    gives any member of the group `<groupname>` read, write, and execute
    privileges on the specified directory, where `<groupname>` is the name
    of the host group you created in the previous step, as displayed by the
   `docker-group.sh` script.

## Mapping a user inside a Docker image onto a host user

It is simple to set and use up a non-root user inside a Docker image.
This prevents a running container from doing things with escalated
privilege.

But when such a non-root user attempts to write to a file system mounted to the
container, it typically fails with a permissions error, since the user
it maps to on the host system typically does not have write privileges. 
(This will happen, for example, when the container installs the local
codebase.)

There are at least two solutions to this:

- Set the Docker user's numeric user id to the same value as a user on the
  host system with suitable privileges. This is simple, but it is not very 
  flexible or portable. The image must be rebuilt for different user id's, 
  and the same image cannot be reused in environments where the host user 
  id's differ.
  
- Use the Docker user namespace remapping feature. It is
  considerably more complicated, but it is portable and reusable. Changes
  to accommodate different host environments are done *on the host* and not
  in the image.
  
### Docker namespace remapping
  
We use user namespace remapping. It is described in the following articles:

- [Isolate containers with a user namespace](https://docs.docker.com/engine/security/userns-remap/).
  The Docker documentation is somewhat difficult to understand and apply
  on its own.
- [Align user IDs inside and outside Docker with subuser mapping](https://linuxnatives.net/2019/align-user-ids-inside-and-outside-docker-with-subuser-mapping). The scenario/motivation is nearly
  identical to our own here, but the explanation and instructions are 
  cursory.
- [Docker userns-remap and system users on Linux](https://echorand.me/posts/docker-user-namespacing-remap-system-user/). The scenario/motivation is a little different, but
  the explanation is much clearer and more detailed.

#### How it works

This section explains the why and what of the Docker namespace remapping.
For detailed instructions on using it, see
[Setting up docker namespace remapping](#setting-up-docker-namespace-remapping) . 

1. Docker can be configured to use user namespace remapping. This is
   done by specifying the Docker daemon parameter `userns-remap` and
   restarting Docker.
   
   The value of parameter `userns-remap` is the name of a host 
   user (and optionally, its group). This user and group is arbitrary;
   it is an implementation detail of Docker user namespace remapping,
   but it must be an existing user.
   
   Alternatively, use the value `default`, 
   which Docker translates to `dockremap:dockremap`, and automatically
   creates the user and group if necessary, and creates corresponding
   entries in `/etc/subuid` and `/etc/subgid`. Otherwise, the 
   user must manually create the specified user and group and entries
   in `/etc/subuid` and `/etc/subgid`.
   
   We prefer `default` for simplicity.

1. When Docker user namespace remapping is active, it maps _container_ 
   users and groups onto _host_ users and groups according to the user and 
   group numerical id's together with a particular entry in `/etc/subuid` 
   and `/etc/subgid` respectively.
   
   Specifically, Docker maps container user (group) with numerical id `id`
   onto host user (group) with numerical id `start + id`, where `start` is
   the starting user (group) subsidiary id specified in `/etc/subuid` 
   (`/etc/subgid`) _for the user (group) specified by the Docker parameter_
   `userns-remap`.
   
   For example, if 

   - `userns-remap` specifies `dockremap:dockremap`
   - `/etc/subuid` contains a line `dockremap:200000:65536`
   
   then
   
   - user 0 (root) in the container is mapped to host user 200000
   - user 100 in the container is mapped to host user 200100
   - etc. 
   
   (Similarly for group and `/etc/subgid`.)
   
1. In order to know precisely what user/group id are mapped in the host,
   you need to know the user/group id in the container. The easiest way
   to do this is to specify the user/group id's in the image when they
   are created. Using the information in `/etc/sub{u,g}id`, you then
   can compute the mapped host user/group ids as noted above.

1. The host user onto which a container user is mapped will in general
   have no privileges for anything. This is the purpose of Docker user
   namespace remapping: To ensure that all users, including the root user,
   inside a Docker container map onto host users with no privileges by 
   default.
   
1. However, the host _can_ grant privileges to such a mapped user (e.g., 
   write access to certain directories) if it chooses.
   
   To make it easier to manage the privileges granted to a host user
   mapped from a container user, and to identify files created by it,
   etc., it is best to create host usernames and group names for the
   (so far) purely numerical user uid and group gid's that are mapped.
   
Notes:

1. The host user and group specified in the Docker parameter 
  `userns-remap` are used _only_ to select the appropriate information 
  from `/etc/subuid` and `/etc/subgid`. This user and group are
  not directly related to the mapped host users and groups. In 
  particular, the privileges of this user and group do **not**
  affect the privileges of mapped users and groups.
   
1. Only the numerical ids of users and groups inside the container
  are relevant to the mapping. Their names do not participate in the
  mapping, and so can be chosen to be anything convenient.

## Bonus information

To delete a user:

```
sudo userdel USERNAME
```

To delete a group:

```
sudo groupdel GROUPNAME
```





