#!/usr/bin/env bash
# Build_app.sh
#
# Compute:
# - build the code 
# - create a $ROOT/target/compute/$APP_NAME directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
{% import "build.j2_macro" as m with context %}
m.build_common

if is_deploy_compute; then
  build_rsync $APP_SRC_DIR
else
  cd $APP_SRC_DIR
  docker image rm ${TF_VAR_prefix}-${APP_NAME}:latest
  docker build -t ${TF_VAR_prefix}-${APP_NAME}:latest .
  exit_on_error "docker build"
fi  
