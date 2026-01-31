#!/usr/bin/env bash
# Build_app.sh
#
# Compute:
# - build the code 
# - create a $ROOT/target/compute/$APP_NAME directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/../../bin/build_common.sh

java_build_common

mvn package
exit_on_error

if is_deploy_compute; then
  cp nginx_app.locations $TARGET_DIR/compute/compute
  build_rsync target
else
  docker image rm ${TF_VAR_prefix}-${APP_NAME}:latest
  docker build -t ${TF_VAR_prefix}-${APP_NAME}:latest .
  exit_on_error
fi  
