# Base image must be 18.04. Some packages we want do not exist in 20.04.
FROM ubuntu:18.04

LABEL Maintainer="Rod Glover <rglover@uvic.ca>"

# Get set to install packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update

# Install Ubuntu packages
RUN apt-get install -yq \
        python2.7 \
        python2.7-dev \
        python-pip \
        build-essential \
        libhdf5-dev \
        libgdal-dev \
        libnetcdf-dev \
        git \
        && \
    rm -rf /var/lib/apt/lists/*

# Build arguments (scope limited to build). If you wish to use a different user name,
# group name, or user home dir, override these in the build command.
ARG USERNAME=dockeragent
ARG GROUPNAME=${USERNAME}
ARG USER_DIR=/opt/${USERNAME}

# Environment variables (scope NOT limited to build). These and are set here so that
# subsequent builds and containers have access to these build arguments.
ENV USERNAME=${USERNAME}
ENV GROUPNAME=${GROUPNAME}
ENV USER_DIR=${USER_DIR}

# Create non-privileged user.
RUN groupadd -r ${GROUPNAME} && \
    useradd -r -d ${USER_DIR} -g ${GROUPNAME} ${USERNAME} && \
    mkdir -p ${USER_DIR} && \
    chown ${USERNAME}:${GROUPNAME} ${USER_DIR}

# Insall Python build packages
RUN pip install --upgrade pip setuptools wheel

# Set up environment variables for Python installs and builds
ENV CPLUS_INCLUDE_PATH /usr/include/gdal
ENV C_INCLUDE_PATH /usr/include/gdal

# Install primary dependencies (separate RUN statement for GDAL is required).
# Other project dependencies will be installed by the images based on this one.
RUN pip install --no-binary :all: numpy Cython==0.22 gdal==2.2
RUN pip install --no-binary :all: h5py

USER ${USERNAME}
