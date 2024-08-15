#!/bin/bash

mkdir -p /var/run/sogo
touch /var/run/sogo/sogo.pid
chown -R sogo:sogo /var/run/sogo

# Check if a personalized configuration exists
CONFIG_PATH="/srv/etc/sogo.conf"
DEFAULT_CONFIG="/etc/sogo/sogo.conf.default"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Configuration SOGo personnalisée non trouvée. Création d'une configuration par défaut."
    cp "$DEFAULT_CONFIG" "$CONFIG_PATH"
else
    echo "Utilisation de la configuration SOGo personnalisée."
fi

cp "$CONFIG_PATH" /etc/sogo/sogo.conf

#Solve libssl bug for Mail View
if [[ -z "${LD_PRELOAD}" ]]; then
	LIBSSL_LOCATION=$(find / -type f -name "libssl.so.*" -print -quit);echo "LD_PRELOAD=$LIBSSL_LOCATION" >> /etc/default/sogo
	echo "LD_LIBRARY_PATH=/usr/local/lib/sogo:/usr/local/lib:$LD_LIBRARY_PATH" >> /etc/default/sogo
	export LD_PRELOAD=$LIBSSL_LOCATION
else
	echo "LD_PRELOAD=$LD_PRELOAD" >> /etc/default/sogo
	echo "LD_LIBRARY_PATH=/usr/local/lib/sogo:/usr/local/lib:$LD_LIBRARY_PATH" >> /etc/default/sogo
	export LD_PRELOAD=$LD_PRELOAD
fi

# Copy distribution config files to /srv as example
mkdir -p /srv/etc /etc/sogo
cp /etc/sogo/sogo.conf /srv/etc/sogo.conf.orig

# Copy back administrator's configuration
cp /srv/etc/sogo.conf /etc/sogo/sogo.conf

# Create SOGo home directory if missing
mkdir -p /srv/lib/sogo
chown -R sogo /srv/lib/sogo

# Copy crontab to /srv as example
cp /etc/cron.d/sogo /srv/etc/cron.orig

# Load crontab
cp /srv/etc/cron /etc/cron.d/sogo
printf "\n" >> /etc/cron.d/sogo

# load env
. /usr/share/GNUstep/Makefiles/GNUstep.sh

# Run SOGo in foreground
exec su -s /bin/sh -c '/usr/local/sbin/sogod' sogo