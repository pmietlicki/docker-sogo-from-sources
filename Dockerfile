# Use an official base image
FROM ubuntu as builder

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Paris

# Install dependencies for the build process
RUN apt-get update && apt-get install -y curl jq

# Retrieve the latest SOGo version and write it to a file
RUN curl --silent "https://api.github.com/repos/Alinto/sogo/releases/latest" | \
    jq -r '.tag_name' | cut -c 6- > /tmp/sogo_version

RUN cat /tmp/sogo_version | cut -c 1 > /tmp/sogo_maj_version

# Install build dependencies and fetch SOGo and SOPE sources
RUN apt-get install -y curl gnupg lsb-release gettext-base --no-install-recommends && \
    echo "deb [trusted=yes] http://www.axis.cz/linux/debian $(lsb_release -sc) sogo-v$(cat /tmp/sogo_maj_version)" > /etc/apt/sources.list.d/sogo.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 608F5293A04BE668 && \
    apt-get update && apt-get install -y gnustep-make gnustep-base-runtime libgnustep-base-dev pkg-config make gobjc libz-dev zlib1g-dev libpq-dev libmysqlclient-dev libcurl4-openssl-dev libsodium-dev libxml2-dev libssl-dev libldap2-dev libzip-dev mysql-client postgresql-client tmpreaper python3-m2crypto python3-simplejson python3-vobject python3-dateutil postgresql-server-dev-all libmemcached-dev libcurl4-openssl-dev libwbxml2-* tzdata libytnef0 libytnef0-dev --no-install-recommends && \
    curl -L "https://codeload.github.com/Alinto/sope/tar.gz/refs/tags/SOPE-$(cat /tmp/sogo_version)" -o sope.tar.gz && \
    curl -L "https://codeload.github.com/Alinto/sogo/tar.gz/refs/tags/SOGo-$(cat /tmp/sogo_version)" -o SOGo.tar.gz && \
    tar -xf sope.tar.gz && \
    tar -xf SOGo.tar.gz && \
    mv sope-SOPE-$(cat /tmp/sogo_version) /tmp/SOPE && \
    mv sogo-SOGo-$(cat /tmp/sogo_version) /tmp/SOGo && \
    cd /tmp/SOPE && ./configure --with-gnustep --enable-debug --disable-strip && make && make install && \
    cd /tmp/SOGo && ./configure --enable-debug --disable-strip && make && make install

# Start the final image from a clean state
FROM ubuntu

# Copy the built artifacts from the builder stage
COPY --from=builder /usr/local/lib/GNUstep /usr/local/lib/GNUstep
COPY --from=builder /usr/local/sbin /usr/local/sbin

# Install runtime dependencies
RUN apt-get update && apt-get install -y apache2 memcached libssl-dev gettext-base --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    a2enmod headers proxy proxy_http rewrite ssl && \
    groupadd --system sogo && \
    useradd --system --gid sogo sogo && \
    install -o sogo -g sogo -m 755 -d /var/run/sogo /var/spool/sogo /var/log/sogo

# Check the SOGo installation directory and create if necessary
RUN mkdir -p /usr/lib/GNUstep/ && \
    ln -s /usr/local/lib/GNUstep/SOGo /usr/lib/GNUstep/SOGo && \
    ln -s /usr/local/sbin/sogo-tool /usr/sbin/sogo-tool && \
    ln -s /usr/local/sbin/sogo-ealarms-notify /usr/sbin/sogo-ealarms-notify && \
    ln -s /usr/local/sbin/sogo-slapd-sockd /usr/sbin/sogo-slapd-sockd

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libssl.so
ENV USEWATCHDOG=YES

# Configure services
COPY sogod.sh /etc/service/sogod/run
COPY apache2.sh /etc/service/apache2/run
COPY memcached.sh /etc/service/memcached/run
COPY memcached-control.sh /etc/my_init.d/

RUN chmod +x /etc/service/sogod/run /etc/service/apache2/run /etc/service/memcached/run && \
    mkdir -p /etc/service/sogod /etc/service/apache2 /etc/service/memcached /etc/my_init.d

# Interface the environment
VOLUME /srv
EXPOSE 80 443 8800

# Copier le script de démarrage dans le conteneur
COPY start_services.sh /start_services.sh

# Rendre le script exécutable
RUN chmod +x /start_services.sh

# Définir le script comme point d'entrée
ENTRYPOINT ["/start_services.sh"]