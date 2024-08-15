#!/bin/sh
exec gosu memcache /usr/bin/memcached -m ${memcached:-64} 2>&1 | tee /var/log/memcached/memcached.log