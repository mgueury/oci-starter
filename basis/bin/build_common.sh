# Called from a build script
if [ "${BASH_SOURCE[1]}" =="" ]; then
  echo "build_common.sh should be called only from a build script via <<. build_common.sh>>"
  exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[1]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/../../starter.sh env -no-auto

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

APP_DIR=`echo ${SCRIPT_DIR} |sed -E "s#(.*)/(.*)#\2#"`
cd $SCRIPT_DIR

if [ "$TF_VAR_deploy_type" == "" ]; then
  . $PROJECT_DIR/starter.sh env
else 
  . $BIN_DIR/shared_bash_function.sh
fi 

if [ -f $PROJECT_DIR/before_build.sh ]; then
  . $PROJECT_DIR/before_build.sh
fi 

if [ "$TF_VAR_app_src_dir" == "" ]; then
  export TF_VAR_app_src_dir="src"
  export APP_TARGET_DIR="target"
else 
  export APP_TARGET_DIR="${TF_VAR_app_src_dir}/target"
fi 
