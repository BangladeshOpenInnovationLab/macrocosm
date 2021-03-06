#!/bin/bash

DATADIR="/var/lib/pgsql/data"

# test if DATADIR has content
if [ ! "$(ls -A $DATADIR)" ]; then
	# Create the en_US.UTF-8 locale.  We need UTF-8 support in the database.
	localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

	echo "Initializing Postgres Database at $DATADIR"
	su postgres sh -lc "initdb --encoding=UTF-8 --locale=en_US.UTF-8"

	su postgres sh -lc "postgres --single -jE" <<-EOSQL
		CREATE USER osm WITH SUPERUSER PASSWORD 'password';
	EOSQL

	# Allow the osm user to connect remotely with a password.
	echo "listen_addresses = '*'" >> "${DATADIR}/postgresql.conf"
	echo "host all osm 0.0.0.0/0 md5" >> "${DATADIR}/pg_hba.conf"

	# Create the apidb database owned by osm.
	su postgres sh -lc "postgres --single -jE" <<-EOSQL
		CREATE DATABASE macrocosm_test OWNER osm;
	EOSQL

	# Start the database server temporarily while we configure the databases.
	su postgres sh -lc "pg_ctl -w start"

	# Configure the macrocosm_test database as the OSM user.
	su postgres sh -lc "psql -U osm macrocosm_test" <<-EOSQL
		\i /install/script/macrocosm-db.sql
	EOSQL

	# Stop the database.
	su postgres sh -lc "pg_ctl -w stop"
fi

SHUTDOWN_COMMAND="echo \"Shutting down postgres\"; su postgres sh -lc \"pg_ctl -w stop\""
trap "${SHUTDOWN_COMMAND}" SIGTERM
trap "${SHUTDOWN_COMMAND}" SIGINT

# Start the database server.
su postgres sh -lc "pg_ctl -w start"

echo "Docker container startup complete"

# Wait for the server to exit.
while test -e "/var/lib/pgsql/data/postmaster.pid"; do
	sleep 0.5
done
