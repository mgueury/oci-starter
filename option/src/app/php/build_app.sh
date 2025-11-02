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

## XXXXX Check Language version

if is_deploy_compute; then
  build_rsync $TF_VAR_app_src_dir
  # Replace the user and password in the start file
  replace_db_user_password_in_file $TARGET_DIR/compute/$APP_DIR/php.ini.append
else
  docker image rm ${TF_VAR_prefix}-app:latest
  docker build -t ${TF_VAR_prefix}-app:latest .
  exit_on_error
fi  
