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
  
### Build args and environment variables

To support a (typically) non-root user, the following build args are defined
in `base-minimal.Dockerfile`:

- `USERNAME`: Name of user. Default: `dockeragent`.
- `GROUPNAME`: Name of user's group. Default: `<USERNAME>`.
- `USER_DIR`: Home directory of user. Default: `/opt/<USERNAME>`.

These build args can be overridden to define a different user, including as
`root`, which yields an UNSAFE (see above) image.

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
  Python packages. Built with `USERNAME=dockeragent`.
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

It is difficult if not impossible to install on an up-to-date workstation a 
suitable environment for running the PDP's tests or the application.

Instead, we can use a Docker container. The images in this repo provide 
suitable bases for these builds.

Since both `pdp` and `pdp_util` need to do this, we present the explanation
of how these containers work in one place, namely here. The actual images and
containers are defined and built in their respective repos.

#### Mechanism

1. The development image is built with all the contents necessary to install 
   and run the package and its tests. 

1. Since we want to run our locally modified code, we can't install the 
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

#### Procedure

This section outlines the procedure used to set up and use a development image.
Individual development images in each repo may have slightly different
procedures.

1. (Once per host environment) Prepare the host environment to map the non-root 
   user in the development image to a host user with the right privileges. 
   This is only necessary to run a development image with write privileges
   to the local filesystem.
  
   For details, see section 
  [Mapping a user inside a Docker image onto a host user](#mapping-a-user-inside-a-docker-image-onto-a-host-user). 
  
    1. Run the script `./supplementary/docker-userns-remap-host.sh`.
       It:
       - creates a user and group on your local machine (the host
        environment) that the Docker non-root user will map onto;
       - adds the user to your own primary group (to give it access to
        the project files);
       - does some magic to set up for the mapping between the Docker
        namespace and your own;
       - prints the username and groupname.
    1. Modify your local `/etc/docker/daemon.json` to include
    
        ```
        {
          "userns-remap": "<username>:<groupname>"
        }
        ```
       where `<username>` and `<groupname>` are taken from the output of the
       script.
    1. Restart Docker:
    
        ```
        sudo systemctl restart docker
        ```
       
        and verify that it restarted:
        
        ```
        sudo systemctl status docker
        ```

1. (Initially; infrequently thereafter) Pull or locally build the Docker 
   image that creates the development environment.

1. (When you wish to run tests or run the application) Run the image, mounting
   the local codebase. Inside the container, run the tests or start the
   application. Running the image and/or running the tests or starting the
   application may be automated by docker-compose and/or by scripts provided
   in the project.

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
  flexible or portable. The image must be rebuilt for different user id's, and 
  the same image cannot be reused in environments where the host user id's 
  differ.
- Use the Docker `userns-remap` feature. This uses some Linux magic to
  "remap" the image/container user id to a user id on the host. It is
  considerably more complicated, but it is portable and reusable. Changes
  to accommodate different host environments are done *on the host* and not
  in the image.
  
We use the second solution (`userns-remap`) for `local-pytest`. Such solutions
are described in the following articles:

- [Align user IDs inside and outside Docker with subuser mapping](https://linuxnatives.net/2019/align-user-ids-inside-and-outside-docker-with-subuser-mapping). The scenario/motivation is nearly
  identical to our own here, but the explanation and instructions are 
  cursory.
- [Docker userns-remap and system users on Linux](https://echorand.me/posts/docker-user-namespacing-remap-system-user/). The scenario/motivation is a little different, but
  the explanation is much clearer and more detailed.
- [Isolate containers with a user namespace](https://docs.docker.com/engine/security/userns-remap/).
  The Docker documentation is somewhat difficult to understand and apply
  on its own.

Based on these articles, I devised the following solution. I believe it to
be fairly general and flexible.

1. Select user name and group name for mapping. Suggest `dockeragent`.
1. In the Docker image(s):
    1. Create a group and user with the selected names.
    1. At the end of the image, run `USE <username>`. Any container
       run from this image cannot escalate privilege beyond what is given
       to the host user it maps to.
1. On the host machine:
    1. Create docker user group (see script).
    1. Create docker user (see script).
    1. Add docker user to the group on the local machine with privileges
     for the files to be modified. This is likely your login user's primary group.
    1. Add `subuid` and `subgid` entries for docker user. This is how
     namespace remapping is done on the host (see script). This is the "magic" part.
    1. Modify `/etc/docker/daemon.json` to include
       ```
        {
          "userns-remap": "<username>"
        }
       ```
    1. Restart Docker:
       ```
       sudo systemctl restart docker
       sudo systemctl status docker
       ```  

The first 4 steps in this procedure can easily be encapsulated in a script.
See `./supplementary/docker-userns-remap-host.sh`.






