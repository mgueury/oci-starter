
#!/usr/bin/env bash
# build.sh
#
# Compute:
# - build the code 
# - create a $TARGET_DIR/compute/app/$APP_NAME directory with the files
# - and a start.sh to start the program
# Docker:
# - build the image
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
# Set the settings. For src/app/xxx or src/app/zzz/xxx or BUILD_HOST=bastion 
if [ -f $SCRIPT_DIR/../../../bin/build_common.sh ]; then
    . $SCRIPT_DIR/../../../bin/build_common.sh
elif [ -f $SCRIPT_DIR/../../../../bin/build_common.sh ]; then
    . $SCRIPT_DIR/../../../../bin/build_common.sh
elif [ -f $HOME/compute/shared_compute.sh ]; then
    . $HOME/compute/shared_compute.sh
fi

cd src
npm install
npm run build
cd ..

mkdir -p html
rm -Rf html/*
cp -r src/build/* html/.

# Common
build_ui