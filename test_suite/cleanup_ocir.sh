SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

echo "-- Cleanup OCIR -------------------------------------------------------------"
. $HOME/.oci_starter_profile
python3 cleanup_ocir.py

echo "-- Docker System Prune ------------------------------------------------------"
docker system prune