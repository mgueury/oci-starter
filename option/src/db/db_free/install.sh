# sudo dnf install -y podman
# podman run -d -p 1521:1522 -p 1522:1522 -p 8443:8443 -p 27017:27017 -e WORKLOAD_TYPE='ATP' -e WALLET_PASSWORD=LiveLab_123 -e ADMIN_PASSWORD=LiveLab_123 --cap-add SYS_ADMIN --device /dev/fuse --name adb-free --volume adb_container_volume:/u01/data container-registry.oracle.com/database/adb-free:latest-23ai
# alias adb-cli="podman exec adb-free adb-cli"

# Doc: https://docs.oracle.com/en/database/oracle/oracle-database/23/xeinl/installing-oracle-database-free.html

# Start the root_install.sh
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

sudo ./install_root.sh