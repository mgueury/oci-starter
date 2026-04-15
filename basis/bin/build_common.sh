BUILD_COMMON_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [ -f $BUILD_COMMON_DIR/../starter.sh ]; then
   . $BUILD_COMMON_DIR/../starter.sh env -no-auto -silent
else 
   echo "ERROR: starter.sh not found"
   exit 1
fi

# Build_common.sh
#!/usr/bin/env bash
if [ "$BIN_DIR" == "" ]; then
  echo "Error: BIN_DIR not set"
  exit 1
fi
if [ "$PROJECT_DIR" == "" ]; then
  echo "Error: PROJECT_DIR not set"
  exit 1
fi

APP_NAME=$(basename $(dirname $0))
APP_SRC_DIR="${APP_NAME}"
APP_COMPUTE_DIR="app/${APP_NAME}"
cd $SCRIPT_DIR

if [ "$TF_VAR_deploy_type" == "" ]; then
  . $PROJECT_DIR/starter.sh env
else 
  . $BIN_DIR/shared_bash_function.sh
fi 

if [ -f $PROJECT_DIR/before_build.sh ]; then
  . $PROJECT_DIR/before_build.sh
fi 
