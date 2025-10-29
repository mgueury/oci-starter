#!/usr/bin/env bash
# Build_app.sh
#
# Compute:
# - build the code 
# - create a $ROOT/target/compute/$APP_DIR directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/../../starter.sh env -no-auto
. $BIN_DIR/build_common.sh

## XXXXX Check Language version

if is_deploy_compute; then
  mkdir -p $TARGET_DIR/compute/$APP_DIR
  rsync -av --progress $TF_VAR_app_src_dir $TARGET_DIR/compute/$APP_DIR --exclude starter --exclude terraform.tfvars
  # Replace the user and password in the start file
  replace_db_user_password_in_file ../../target/compute/$APP_DIR/php.ini.append
else
  docker image rm ${TF_VAR_prefix}-app:latest
  docker build -t ${TF_VAR_prefix}-app:latest .
  exit_on_error
fi  
