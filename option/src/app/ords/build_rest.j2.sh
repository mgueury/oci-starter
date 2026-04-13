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
  null
else
  # No docker build
  {{ m.deploy_oke() }}
fi  
