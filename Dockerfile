FROM phusion/baseimage:master

ENV version=5.0.1

WORKDIR /tmp/build

# download SOPE sources
ADD https://github.com/inverse-inc/sope/archive/SOPE-${version}.tar.gz /tmp/src/sope/sope.tar.gz

# download sogo sources
ADD https://github.com/inverse-inc/sogo/archive/SOGo-${version}.tar.gz /tmp/src/SOGo/SOGo.tar.gz

# add sources for libwbxml for activesync
echo "deb [trusted=yes] http://www.axis.cz/linux/debian focal sogo-v5" > /etc/apt/sources.list.d/sogo.list

# prepare & compile
RUN echo "untar SOPE sources" \
   && tar -xf /tmp/src/sope/sope.tar.gz && mkdir /tmp/SOPE && mv sope-SOPE-${version}/* /tmp/SOPE/. \
   && echo "untar SOGO sources"  \
   && tar -xf /tmp/src/SOGo/SOGo.tar.gz && mkdir /tmp/SOGo && mv sogo-SOGo-${version}/* /tmp/SOGo/. \ 
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
      libwbxml2-0-dbg \
      libwbxml2-dev \
      libwbxml2-utils \
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

RUN ln -s /usr/lib/GNUstep/SOGo /usr/local/lib/GNUstep/SOGo

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