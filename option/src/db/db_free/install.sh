#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

# Install DB_FREE
sudo ./install_root.sh

# Install Table
su - oracle -c "sqlplus $DB_USER/$DB_PASSWORD@$DB_URL" <<EOF
@/home/opc/app/db/oracle
EOF

