#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
export TEST_HOME=$SCRIPT_DIR/test_group_all
. $SCRIPT_DIR/test_suite_shared.sh
export BUILD_COUNT=1

loop_hosted_app_lang() {
    # Maybe remove one compute when all is working
    OPTION_LANG=java
    build_option  
    OPTION_LANG=donet
    build_option  
    OPTION_LANG=go
    build_option  
    OPTION_LANG=python
    build_option  
    OPTION_LANG=nodejs
    build_option  
}

loop_deploy() {
    # HOSTED APP
    OPTION_DB=atp 
    OPTION_GROUP_NAME=none
    OPTION_LANG=java
    OPTION_JAVA_VM=jdk
    OPTION_JAVA_FRAMEWORK=springboot
    OPTION_UI=html
    OPTION_DB=atp 
    loop_hosted_app_lang
}

generate_only() {
    if [ -d $TEST_HOME ]; then    
        echo "$TEST_HOME directory detected"
    else
        echo "ERROR: $TEST_HOME does not exist"
        exit
    fi
    rm -rf $TEST_HOME/compute $TEST_HOME/kubernetes $TEST_HOME/container_instance $TEST_HOME/function
    export GENERATE_ONLY=true
}

if [ "$PROJECT_DIR" != "" ]; then
    echo "ERROR: PROJECT_DIR set. Exiting."
    exit 1
fi

if [ -d $TEST_HOME ]; then
    ELAPSED=0
    while [ ! -f "${TEST_HOME}/terraform_common_env.sh" ] && [ $ELAPSED -lt 3600 ]; do
        echo "Waiting 10 secs that terraform_common_env.sh is available."
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    if [ ! -f "${TEST_HOME}/terraform_common_env.sh" ]; then
        echo "ERROR: ${TEST_HOME}/terraform_common_env.sh not detected after 3600 secs"
        exit 1
    fi

    pre_git_refresh
else  
    mkdir -p $TEST_HOME
    cd $TEST_HOME
    git clone https://github.com/mgueury/oci-starter
    touch inprogress_rerun.sh
    touch ok_rerun.sh
    touch "${TEST_HOME}/terraform_common_env.sh"
fi
# generate_only
cd $TEST_HOME
loop_deploy
# post_test_suite
