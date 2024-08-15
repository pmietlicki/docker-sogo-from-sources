# Stage 1: Build stage with all dependencies and compilation
FROM ubuntu AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

# Install dependencies for the build process
RUN apt-get update && apt-get install -y \
    curl jq gnustep-make gnustep-base-runtime libgnustep-base-dev pkg-config \
    make gobjc libz-dev zlib1g-dev libpq-dev libmysqlclient-dev libcurl4-openssl-dev \
    libsodium-dev libxml2-dev libssl-dev libldap2-dev libzip-dev lsb-release gnupg \
    postgresql-server-dev-all libmemcached-dev libwbxml2-* tzdata libytnef0 libytnef0-dev \
    --no-install-recommends && apt-get clean && rm -rf /var/lib/apt/lists/*

# Retrieve the latest SOGo version and write it to a file
RUN curl --silent "https://api.github.com/repos/Alinto/sogo/releases/latest" | \
    jq -r '.tag_name' | cut -c 6- > /tmp/sogo_version
RUN cat /tmp/sogo_version | cut -c 1 > /tmp/sogo_maj_version

# Add the SOGo repository and install additional build dependencies
RUN echo "deb [trusted=yes] http://www.axis.cz/linux/debian $(lsb_release -sc) sogo-v$(cat /tmp/sogo_maj_version)" > /etc/apt/sources.list.d/sogo.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 608F5293A04BE668 && \
    apt-get update && apt-get install -y \
    mysql-client postgresql-client tmpreaper python3-m2crypto python3-simplejson \
    python3-vobject python3-dateutil --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and compile SOPE
RUN curl -L "https://codeload.github.com/Alinto/sope/tar.gz/refs/tags/SOPE-$(cat /tmp/sogo_version)" -o sope.tar.gz && \
    tar -xf sope.tar.gz && cd sope-SOPE-$(cat /tmp/sogo_version) && \
    ./configure --with-gnustep --enable-debug --disable-strip && make -j$(nproc) && make install

# Download and compile SOGo
RUN curl -L "https://codeload.github.com/Alinto/sogo/tar.gz/refs/tags/SOGo-$(cat /tmp/sogo_version)" -o SOGo.tar.gz && \
    tar -xf SOGo.tar.gz && cd sogo-SOGo-$(cat /tmp/sogo_version) && \
    ./configure --enable-debug --disable-strip && make -j$(nproc) && make install

# Stage 2: Final minimal image
FROM ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libssl.so
ENV USEWATCHDOG=YES

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    gosu procps apache2 memcached lsb-release gnupg supervisor dos2unix \
    libssl-dev gnustep-base-runtime gettext-base --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the compiled binaries and libraries from the build stage
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/sbin /usr/local/sbin
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /usr/local/share /usr/local/share

# Configure Apache, SOGo, and other dependencies
RUN a2enmod headers proxy proxy_http rewrite ssl && \
    echo "/usr/local/lib/sogo" > /etc/ld.so.conf.d/sogo.conf && ldconfig && \
    groupadd --system sogo && useradd --system --gid sogo sogo && \
    install -o sogo -g sogo -m 755 -d /var/run/sogo /var/spool/sogo /var/log/sogo && \
    mkdir -p /usr/lib/GNUstep/ && \
    ln -s /usr/local/lib/GNUstep/SOGo /usr/lib/GNUstep/SOGo && \
    ln -s /usr/local/sbin/sogo-tool /usr/sbin/sogo-tool && \
    ln -s /usr/local/sbin/sogo-ealarms-notify /usr/sbin/sogo-ealarms-notify && \
    ln -s /usr/local/sbin/sogo-slapd-sockd /usr/sbin/sogo-slapd-sockd

# Create necessary directories for services
RUN mkdir -p /etc/service/sogod /etc/service/apache2 /etc/service/memcached

# Copy scripts and configuration files
COPY sogod.sh /etc/service/sogod/run
COPY apache2.sh /etc/service/apache2/run
COPY memcached.sh /etc/service/memcached/run
COPY sogo.conf.default /etc/sogo/sogo.conf.default
COPY supervisord.conf /etc/supervisord.conf

# Set file permissions and convert scripts to Unix format
RUN chmod +x /etc/service/sogod/run /etc/service/apache2/run /etc/service/memcached/run && \
    mkdir -p /var/log/apache2 /var/log/sogo /var/log/memcached && \
    dos2unix /etc/service/sogod/run /etc/service/apache2/run /etc/service/memcached/run /etc/sogo/sogo.conf.default

# Set up volume and expose ports
VOLUME /srv
EXPOSE 80 443 8800

# Set entry point
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]