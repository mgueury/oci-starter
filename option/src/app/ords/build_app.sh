#!/usr/bin/env bash
# Build_app.sh
#
# Compute:
# - build the code 
# - create a $ROOT/target/compute/$APP_DIR directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
. ../../bin/build_common.sh

if is_deploy_compute; then
  sed "s&##ORDS_URL##&$ORDS_URL&" nginx_app.locations > $TARGET_DIR/compute/compute/nginx_app.locations
else
  echo "No docker image needed"
fi  
