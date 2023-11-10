#!/bin/bash

# Contrôler l'état de Memcached
/etc/my_init.d/memcached-control.sh

# Démarrer SOGo
/etc/service/sogod/run &

# Démarrer Apache
/etc/service/apache2/run &

# Démarrer Memcached
/etc/service/memcached/run &

# Attendre que tous les processus en arrière-plan se terminent
wait