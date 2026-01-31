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

## XXXXX Check Language version

if is_deploy_compute; then
  build_rsync $APP_SRC_DIR
  # Replace the user and password in the start file
  replace_db_user_password_in_file $TARGET_DIR/compute/$APP_NAME/php.ini.append
else
  docker image rm ${TF_VAR_prefix}-${APP_NAME}:latest
  docker build -t ${TF_VAR_prefix}-${APP_NAME}:latest .
  exit_on_error
fi  
