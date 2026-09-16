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

# Ex: src/app/rest            -> rest            -> rest
# Ex: src/app/restaurant/rest -> restaurant/rest -> restaurant-rest
export APP_DIR="${SCRIPT_DIR#*/app/}"
export APP_NAME="${APP_DIR//\//-}"
cd $SCRIPT_DIR
title "Build App - $APP_NAME"

if [ "$TF_VAR_deploy_type" == "" ]; then
    . $PROJECT_DIR/starter.sh env
else 
    . $BIN_DIR/shared_bash_function.sh
fi 

# APP_PROJECT is empty for root components and is the first directory segment
# for project-scoped components. Database credentials remain shared.
if [[ "$APP_DIR" == */* ]]; then
    export APP_PROJECT="${APP_DIR%%/*}"
    export K8S_APP_PREFIX="${TF_VAR_prefix}-${APP_PROJECT}"
else
    export APP_PROJECT=""
    export K8S_APP_PREFIX="${TF_VAR_prefix}"
fi


if [ -f $PROJECT_DIR/before_build.sh ]; then
    . $PROJECT_DIR/before_build.sh
fi 
