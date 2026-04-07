#!/usr/bin/env bash
if [ "$PROJECT_DIR" == "" ]; then
  echo "ERROR: PROJECT_DIR undefined. Please use starter.sh deploy compute"
  exit 1
fi  
cd $PROJECT_DIR
. starter.sh env -silent

echo "COMPUTE_IP=$COMPUTE_IP"

cp $TARGET_DIR/tf_env.sh target/compute/compute/.
scp_via_bastion "target/compute/*" opc@$COMPUTE_IP:/home/opc/.
ssh -o StrictHostKeyChecking=no -oProxyCommand="$BASTION_PROXY_COMMAND" opc@$COMPUTE_IP "bash compute/compute_init.sh 2>&1 | tee -a compute/compute_init.log"
exit_on_error "Deploy Compute - ssh"

