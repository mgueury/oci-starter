#!/usr/bin/env bash
# Build_ui.sh
#
# Compute:
# - build the code 
# - create a $ROOT/compute/ui directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [ -f $SCRIPT_DIR/../../bin/build_common.sh ]; then
    . $SCRIPT_DIR/../../bin/build_common.sh
elif [ -f $HOME/compute/shared_compute.sh ]; then
    . $HOME/compute/shared_compute.sh
fi        

build_ui