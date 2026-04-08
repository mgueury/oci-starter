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

cd rest
java_build_common

mvn package
exit_on_error

if is_deploy_compute; then
    cp nginx_app.locations $TARGET_DIR/compute/compute
    build_rsync target
else
    {{ m.build_docker() }}
fi  
