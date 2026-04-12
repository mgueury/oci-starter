#!/usr/bin/env bash
if [ "$PROJECT_DIR" == "" ]; then
  echo "ERROR: PROJECT_DIR undefined. Please use starter.sh deploy compute"
  exit 1
fi  
cd $PROJECT_DIR
. starter.sh env -silent

echo "COMPUTE_IP=$COMPUTE_IP"

# Create the target/compute directory
$COMPUTE_DIR=$TARGET_DIR/compute
mkdir -p $COMPUTE_DIR
cp -R $BIN_DIR/compute $COMPUTE_DIR/.
cp $TARGET_DIR/tf_env.sh $COMPUTE_DIR/compute/.

scp_via_bastion "target/compute/*" opc@$COMPUTE_IP:/home/opc/.
ssh -o StrictHostKeyChecking=no -oProxyCommand="$BASTION_PROXY_COMMAND" opc@$COMPUTE_IP "bash compute/compute_install.sh 2>&1 | tee -a compute/compute_install.log"
exit_on_error "Deploy Compute - ssh"

