#!/bin/bash

set -x

if [ "$#" -ne 1 ]; then
    echo "usage: <import|run>"
    echo "commands:"
    echo "    import: Set up the database and import /data.osm.pbf"
    echo "    run: Runs Apache and renderd to serve tiles at /tile/{z}/{x}/{y}.png"
    echo "environment variables:"
    echo "    THREADS: defines number of threads used for importing / tile rendering"
    echo "    UPDATES: consecutive updates (enabled/disabled)"
    exit 1
fi

if [ "$1" = "run" ]; then
    # Clean /tmp
    rm -rf /tmp/*
	
	# Register that data has changed for mod_tile caching purposes
    touch /var/lib/mod_tile/planet-import-complete

    # Configure Apache CORS
    if [ "$ALLOW_CORS" == "enabled" ] || [ "$ALLOW_CORS" == "1" ]; then
        echo "export APACHE_ARGUMENTS='-D ALLOW_CORS'" >> /etc/apache2/envvars
    fi

    # Initialize PostgreSQL and Apache    
    service apache2 restart    

    # Configure renderd threads
    sed -i -E "s/num_threads=[0-9]+/num_threads=${THREADS:-4}/g" /usr/local/etc/renderd.conf

    # Run while handling docker stop's SIGTERM
    stop_handler() {
        kill -TERM "$child"
    }
    trap stop_handler SIGTERM

    sudo -u renderer renderd -f -c /usr/local/etc/renderd.conf &
    child=$!
    wait "$child" 

    exit 0
fi

echo "invalid command"
exit 1
