FROM ubuntu:bionic-20191010 as docker-gitlab-base

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=12.5.2

ENV GITLAB_VERSION=${VERSION} \
    RUBY_VERSION=2.6 \
    GOLANG_VERSION=1.12.12 \
    GITLAB_SHELL_VERSION=10.2.0 \
    GITLAB_WORKHORSE_VERSION=8.14.1 \
    GITLAB_PAGES_VERSION=1.12.0 \
    GITALY_SERVER_VERSION=1.72.1 \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    GITLAB_CACHE_DIR="/etc/docker-gitlab" \
    RAILS_ENV=production \
    NODE_ENV=production

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_BUILD_DIR="${GITLAB_CACHE_DIR}/build" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime"

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      wget ca-certificates apt-transport-https gnupg2
RUN set -ex && \
 apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E1DD270288B4E6030699E45FA1715D88E1DF1F24 \
 && echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu bionic main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6 \
 && echo "deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu bionic main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8B3981E7A6852F782CC4951600A6F0A3C300EE8C \
 && echo "deb http://ppa.launchpad.net/nginx/stable/ubuntu bionic main" >> /etc/apt/sources.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
 && wget --quiet -O - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - \
 && echo 'deb https://deb.nodesource.com/node_12.x bionic main' > /etc/apt/sources.list.d/nodesource.list \
 && wget --quiet -O - https://dl.yarnpkg.com/debian/pubkey.gpg  | apt-key add - \
 && echo 'deb https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list \
 && set -ex \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -o Acquire::Retries=3 \
      sudo supervisor logrotate locales curl \
      nginx openssh-server postgresql-client-10 postgresql-contrib-10 redis-tools \
      git-core ruby${RUBY_VERSION} python3 python3-docutils nodejs yarn gettext-base graphicsmagick \
      libpq5 zlib1g libyaml-0-2 libssl1.0.0 \
      libgdbm5 libreadline7 libncurses5 libffi6 \
      libxml2 libxslt1.1 libcurl4 libicu60 libre2-dev tzdata unzip libimage-exiftool-perl \
 && update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
 && locale-gen en_US.UTF-8 \
 && DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales \
 && gem install --no-document bundler -v 1.17.3 \
 && rm -rf /var/lib/apt/lists/*

COPY assets/build/ ${GITLAB_BUILD_DIR}/
RUN bash ${GITLAB_BUILD_DIR}/install.sh

COPY assets/runtime/ ${GITLAB_RUNTIME_DIR}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

LABEL \
    maintainer="jklos@netsuite.com" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.name=gitlab \
    org.label-schema.vendor=netsuite \
    org.label-schema.url="https://gitlab.eng.netsuite.com/devops/ns-docker-gitlab" \
    org.label-schema.vcs-url="https://gitlab.eng.netsuite.com/devops/ns-docker-gitlab.git" \
    org.label-schema.vcs-ref=${VCS_REF} \
    com.netsuite.gitlab.license=MIT

EXPOSE 22/tcp 80/tcp 443/tcp

VOLUME ["${GITLAB_DATA_DIR}", "${GITLAB_LOG_DIR}"]
WORKDIR ${GITLAB_INSTALL_DIR}
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:start"]

FROM docker-gitlab-base
RUN apt-get update \
    && apt-get -y install python3-venv nano \
    && python3 -m venv /home/git/githook_env/ \
    && /home/git/githook_env/bin/pip3 install --no-cache-dir --upgrade pip \
    && /home/git/githook_env/bin/pip3 install --no-cache-dir --extra-index-url https://pypi.eng.netsuite.com/simple/ nsws4py \
    && /home/git/githook_env/bin/pip3 uninstall -y pip pkg-resources setuptools \
    && apt-get -y remove python3-venv \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*
CMD ["app:start"]