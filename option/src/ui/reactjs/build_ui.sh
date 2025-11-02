#!/usr/bin/env bash
# Build_ui.sh
#
# Compute:
# - build the code 
# - create a $ROOT/compute/ui directory with the compiled files
# - and a start.sh to start the program
# Docker:
# - build the image
. ../../bin/build_common.sh

cd src
npm install
npm run build
cd ..

mkdir -p ui
rm -Rf ui/*
cp -r src/build/* ui/.

# Common
build_ui
