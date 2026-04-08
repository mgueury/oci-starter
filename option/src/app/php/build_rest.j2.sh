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
{{ m.build_common() }}

## XXXXX Check Language version

cd rest
if is_deploy_compute; then
    build_rsync $APP_SRC_DIR
    # Replace the user and password in the start file
    replace_db_user_password_in_file $TARGET_DIR/compute/$APP_NAME/php.ini.append
else
    {{ m.build_docker() }}
fi  
