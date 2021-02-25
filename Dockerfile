FROM phusion/baseimage:master

ENV version=5.0.1

WORKDIR /tmp/build

# download SOPE sources
ADD https://github.com/inverse-inc/sope/archive/SOPE-${version}.tar.gz /tmp/src/sope/sope.tar.gz

# download sogo sources
ADD https://github.com/inverse-inc/sogo/archive/SOGo-${version}.tar.gz /tmp/src/SOGo/SOGo.tar.gz

# prepare & compile
RUN echo "untar SOPE sources" \
   && tar -xf /tmp/src/sope/sope.tar.gz && mkdir /tmp/SOPE && mv sope-SOPE-${version}/* /tmp/SOPE/. \
   && echo "untar SOGO sources"  \
   && tar -xf /tmp/src/SOGo/SOGo.tar.gz && mkdir /tmp/SOGo && mv sogo-SOGo-${version}/* /tmp/SOGo/. \ 
   && echo "install required packages" \
   && apt-get update  \
   && apt-get install -qy --no-install-recommends \
      gnustep-make \
      gnustep-base-common \
      libgnustep-base-dev \
      make \
      gobjc \
      libxml2-dev \
      libssl-dev \
      libldap2-dev \
      postgresql-server-dev-all \
      libmemcached-dev \
      libcurl4-openssl-dev \
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
   && echo "register sogo library" \
   && echo "/usr/lib/sogo" > /etc/ld.so.conf.d/sogo.conf  \
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