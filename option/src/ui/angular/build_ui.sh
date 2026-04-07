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
. $SCRIPT_DIR/../../bin/build_common.sh

cd ui/src
npm install
npm install @angular/cli
node_modules/.bin/ng build
cd ..

mkdir -p html
rm -Rf html/*
cp -r src/dist/example-app/* html/.

# Common
build_ui
