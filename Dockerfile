FROM phusion/baseimage:master

RUN echo $(curl --silent "https://api.github.com/repos/inverse-inc/sogo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 6-) > /tmp/sogo_version

ENV SOGO_VERSION=5.2.0
RUN echo $SOGO_VERSION > /tmp/sogo_version

RUN echo $(curl --silent "https://api.github.com/repos/inverse-inc/sogo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 6- | head -c 1) > /tmp/sogo_maj_version

ENV MAJ_VERSION=5
RUN echo $MAJ_VERSION > /tmp/sogo_maj_version

WORKDIR /tmp/build

# add sources for libwbxml for activesync
RUN echo "deb [trusted=yes] http://www.axis.cz/linux/debian $(lsb_release -sc) sogo-v$(cat /tmp/sogo_maj_version)" > /etc/apt/sources.list.d/sogo.list

# download, prepare & compile
RUN echo "download SOPE sources" \
   && mkdir -p /tmp/src/sope \
   && curl -LJ https://github.com/inverse-inc/sope/archive/SOPE-$(cat /tmp/sogo_version).tar.gz -o /tmp/src/sope/sope.tar.gz -s \
   && echo "download SOGo sources" \
   && mkdir -p /tmp/src/SOGo \
   && curl -LJ https://github.com/inverse-inc/sogo/archive/SOGo-$(cat /tmp/sogo_version).tar.gz -o /tmp/src/SOGo/SOGo.tar.gz -sf \
   && echo "untar SOPE sources" \
   && tar -xf /tmp/src/sope/sope.tar.gz && mkdir /tmp/SOPE && mv sope-SOPE-$(cat /tmp/sogo_version)/* /tmp/SOPE/. \
   && echo "untar SOGO sources"  \
   && tar -xf /tmp/src/SOGo/SOGo.tar.gz && mkdir /tmp/SOGo && mv sogo-SOGo-$(cat /tmp/sogo_version)/* /tmp/SOGo/. \ 
   && echo "install required packages" \
   && apt-get update --allow-unauthenticated \
   && apt-get install --allow-unauthenticated -qy --no-install-recommends \
      gnustep-make \
      gnustep-base-runtime \
      libgnustep-base-dev \
      make \
      gobjc \
      libz-dev \
      zlib1g-dev \
      libpq-dev \
      libmysqlclient-dev \
      libcurl4-openssl-dev \
      libsodium-dev \
      libxml2-dev \
      libssl-dev \
      libldap2-dev \
      libzip-dev \
      mysql-client \
      postgresql-client \
      tmpreaper \
      python3-m2crypto \
      python3-simplejson \
      python3-vobject \
      python3-dateutil \
      postgresql-server-dev-all \
      libmemcached-dev \
      libcurl4-openssl-dev \
      libwbxml2-0 \
      libwbxml2-dev \
      tzdata \
   && echo "compiling sope & sogo" \
   && cd /tmp/SOPE  \
   && ./configure --with-gnustep --enable-debug --disable-strip  \
   && make  \
   && make install  \
   && cd /tmp/SOGo  \
   && ./configure --enable-debug --disable-strip  \
   && make  \
   && make install \
   && echo "compiling activesync support" \
   && cd /tmp/SOGo/ActiveSync \
   && make \
   && make install \
   && echo "register sogo library" \
   && echo "/usr/local/lib/sogo" > /etc/ld.so.conf.d/sogo.conf  \
   && ldconfig \
   && echo "create user sogo" \
   && groupadd --system sogo && useradd --system --gid sogo sogo \
   && echo "create directories and enforce permissions" \
   && install -o sogo -g sogo -m 755 -d /var/run/sogo  \
   && install -o sogo -g sogo -m 750 -d /var/spool/sogo  \
   && install -o sogo -g sogo -m 750 -d /var/log/sogo

# Install Apache from repository
RUN apt-get update && \
    apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y --force-yes && \
    apt-get install -y --no-install-recommends gettext-base apache2 memcached libssl-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Activate required Apache modules
RUN a2enmod headers proxy proxy_http rewrite ssl

# Move SOGo's data directory to /srv
RUN usermod --home /srv/lib/sogo sogo

# Add link for Apache config and cron
RUN rm -rf /usr/lib/GNUstep/SOGo
RUN ln -s /usr/local/lib/GNUstep/SOGo /usr/lib/GNUstep/SOGo
RUN ln -s /usr/local/sbin/sogo-tool /usr/sbin/sogo-tool
RUN ln -s /usr/local/sbin/sogo-ealarms-notify /usr/sbin/sogo-ealarms-notify
RUN ln -s /usr/local/sbin/sogo-slapd-sockd /usr/sbin/sogo-slapd-sockd 

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libssl.so
ENV USEWATCHDOG=YES

# SOGo daemons
RUN mkdir /etc/service/sogod /etc/service/apache2 /etc/service/memcached
ADD sogod.sh /etc/service/sogod/run
ADD apache2.sh /etc/service/apache2/run
ADD memcached.sh /etc/service/memcached/run

RUN chmod +x /etc/service/sogod/run
RUN chmod +x /etc/service/apache2/run
RUN chmod +x /etc/service/memcached/run

# Make GATEWAY host available, control memcached startup
RUN mkdir -p /etc/my_init.d
ADD memcached-control.sh /etc/my_init.d/

# Interface the environment
VOLUME /srv
EXPOSE 80 443 8800

# Baseimage init process
ENTRYPOINT ["/sbin/my_init"]
