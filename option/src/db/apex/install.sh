#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
. $HOME/compute/shared_compute.sh

# Install APEX and DBMS_CLOUD
sudo su - oracle -c "export DB_PASSWORD=\"$DB_PASSWORD\"; export DB_URL=\"$DB_URL\"; $SCRIPT_DIR/oracle_install_apex.sh"
sudo su - root -c "export DB_PASSWORD=\"$DB_PASSWORD\"; $SCRIPT_DIR/root_install_apex.sh"

install_instant_client
sqlplus -L $DB_USER/$DB_PASSWORD@DB @oracle.sql $DB_PASSWORD