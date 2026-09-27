#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. $HOME/compute/shared_compute.sh
install_instant_client

# Create schema USER
db_schema_create

echo "DB_USER=$DB_USER"
echo "DB_SCHEMA=$DB_SCHEMA"
export TNS_ADMIN=$SCRIPT_DIR
sqlplus -L $DB_SCHEMA/$DB_PASSWORD@DB @oracle.sql $DB_PASSWORD
