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

if [ "$TF_VAR_java_vm" == "graalvm-native" ]; then
  mvn package -Dpackaging=native-image
else 
  mvn package 
fi
exit_on_error  

if is_deploy_compute; then
  build_rsync target
else
  docker image rm ${TF_VAR_prefix}-${APP_NAME}:latest
  if [ "$TF_VAR_java_vm" == "graalvm-native" ]; then
    docker build -f Dockerfile.native -t ${TF_VAR_prefix}-${APP_NAME}:latest .
  else
    docker build -t ${TF_VAR_prefix}-${APP_NAME}:latest . 
  fi
  exit_on_error    
fi  
