# `pcic/pdp-prod-base` is built by the GitHub workflow `docker-publish`.
# In the workflow, this image is built *after* that image.
FROM pcic/pdp-prod-base

LABEL Maintainer="Rod Glover <rglover@uvic.ca>"

# Get set to install packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update

# Set the locale for PostgreSQL
RUN apt-get -y install locales && \
    locale-gen en_CA.utf8
ENV LANG en_CA.utf8
ENV LANGUAGE en_CA:en
ENV LC_ALL en_CA.UTF-8

# Make legacy Ubuntu 18.04 postgres-9.5 packages available.
# These enable us to reproduce the production environment fairly closely.
RUN apt-get install -y curl ca-certificates gnupg && \
    curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo 'deb http://apt.postgresql.org/pub/repos/apt bionic-pgdg main' >/etc/apt/sources.list.d/pgdg.list && \
    apt-get update

# Install Ubuntu PostgreSQL packages
RUN apt-get install -yq \
        libpq-dev \
        postgresql-plpython-9.5 \
        postgresql-9.5-postgis-2.4 \
        && \
    rm -rf /var/lib/apt/lists/*

