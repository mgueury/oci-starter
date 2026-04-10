#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
. $HOME/compute/tf_env.sh
export JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL=$JDBC_URL

# If build on host
if [ -d target ]; then
    cd target
fi

# Start Java with Native or JIT (JDK/GraalVM)
if [ "$TF_VAR_java_vm" == "graalvm-native" ]; then
  ./helidon -Doracle.jdbc.fanEnabled=false > app.log 2>&1 
else  
  java -jar helidon.jar -Doracle.jdbc.fanEnabled=false > app.log 2>&1
  # Record settings for GraalVM Native
  # java -Doracle.jdbc.fanEnabled=false -agentlib:native-image-agent=config-output-dir=/tmp/config -jar helidon.jar 
fi
