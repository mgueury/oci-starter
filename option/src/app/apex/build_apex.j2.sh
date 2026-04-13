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

if is_deploy_compute; then
    sed "s&##ORDS_URL##&$ORDS_URL&" nginx_app.locations > $TARGET_DIR/app/ui/nginx_app.locations
    sed -i "s&##ORDS_HOST##&$ORDS_HOST&" $TARGET_DIR/app/ui/nginx_app.locations
    build_rsync $APP_SRC_DIR
else
    # No docker build
    {{ m.deploy_oke() }}
fi  
