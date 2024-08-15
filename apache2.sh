#!/bin/sh

# Copy distribution config files to /srv as example
mkdir -p /srv/etc
if [ ! -f /etc/apache2/conf-available/SOGo.conf ]; then
	curl https://raw.githubusercontent.com/Alinto/sogo/master/Apache/SOGo.conf --output /etc/apache2/conf-available/SOGo.conf --silent
fi
cp /etc/apache2/conf-available/SOGo.conf /srv/etc/apache-SOGo.conf.orig

# Check if custom config exists and copy, else enable default config
if [ -f /srv/etc/apache-SOGo.conf ]; then
	cp /srv/etc/apache-SOGo.conf /etc/apache2/conf-enabled/SOGo.conf
else
	a2enconf SOGo.conf
fi

# Run apache in foreground
exec /usr/sbin/apache2ctl -D FOREGROUND | tee /var/log/apache2/apache2.log