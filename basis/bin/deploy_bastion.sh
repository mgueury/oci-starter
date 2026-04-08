#!/usr/bin/env bash
if [ "$PROJECT_DIR" == "" ]; then
  echo "ERROR: PROJECT_DIR undefined. Please use starter.sh deploy bastion"
  exit 1
fi  
cd $PROJECT_DIR
. starter.sh env -silent

function scp_or_rsync() {
    if command -v rsync &> /dev/null; then
        rsync -av -e "ssh -o StrictHostKeyChecking=no -i $TF_VAR_ssh_private_path" $1 opc@$BASTION_IP:.
    else
        scp -r -o StrictHostKeyChecking=no -i $TF_VAR_ssh_private_path $1 opc@$BASTION_IP:/home/opc/.
    fi
}

function scp_bastion() {
    if [ "$TF_VAR_deploy_type" == "public_compute" ] || [ "$TF_VAR_build_host" == "bastion" ]; then
        if [ is_deploy_compute ]; then
            BASTION_DIR=$TARGET_DIR/compute
        else 
            BASTION_DIR=$TARGET_DIR/bastion
        fi 
    else
        BASTION_DIR=$TARGET_DIR/bastion
    fi

    mkdir -p $BASTION_DIR/app
    cp -R src/app/db $BASTION_DIR/app/.

    cp -R $BIN_DIR/compute $BASTION_DIR/.
    cp $TARGET_DIR/tf_env.sh $BASTION_DIR/compute/.
    if [ "$TF_VAR_deploy_type" == "kubernetes" ]; then
        cp $TARGET_DIR/kubeconfig_starter $BASTION_DIR/compute
    fi

    scp_or_rsync $BASTION_DIR/app
    scp_or_rsync $BASTION_DIR/compute    
}

# Try 5 times to copy the files / wait 5 secs between each try
i=0
while [ true ]; do
    scp_bastion
    if [ $? -eq 0 ]; then
        break;
    elif [ "$i" == "5" ]; then
        echo "deploy_bastion.sh: Maximum number of scp retries, ending."
        error_exit
    fi
    sleep 5
    i=$(($i+1))
done

ssh -o StrictHostKeyChecking=no -i $TF_VAR_ssh_private_path opc@$BASTION_IP "bash compute/compute_install.sh 2>&1 | tee -a compute/compute_install.log"
exit_on_error "Deploy Bastion -"
