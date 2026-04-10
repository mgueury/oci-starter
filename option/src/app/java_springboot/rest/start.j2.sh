#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
. $HOME/compute/tf_env.sh

# If build on host
if [ -d target ]; then
    cd target
fi

# Start Java with Native or JIT (JDK/GraalVM)
if [ "$TF_VAR_java_vm" == "graalvm-native" ]; then
  demo > app.log 2>&1 
else  
  java -jar target/demo-0.0.1-SNAPSHOT.jar > app.log 2>&1 
fi