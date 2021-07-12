########################################################################################################
# The image built from this dockerfile does not have a non-root user and is therefore
# UNSAFE TO RUN ON A SENSITIVE HOST (e.g., behind our firewalls).
# DO NOT USE FOR PRODUCTION IMAGES OR ON SELF-HOSTED GitHub WORKFLOW RUNNERS. Instead use one of the
# images with non-root users.
########################################################################################################

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

# Install Python build packages
RUN pip install --upgrade pip setuptools wheel

# Set up environment variables for Python installs and builds
ENV CPLUS_INCLUDE_PATH /usr/include/gdal
ENV C_INCLUDE_PATH /usr/include/gdal
ENV PIP_INDEX_URL https://pypi.pacificclimate.org/simple

# Install primary dependencies (separate RUN statement for GDAL is required).
# Other project dependencies will be installed by the images based on this one.
RUN pip install --no-binary :all: numpy Cython==0.22 gdal==2.2
RUN pip install --no-binary :all: h5py
