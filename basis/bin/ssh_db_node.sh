#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR/..
. env.sh

eval "$(ssh-agent -s)"
ssh-add $TF_VAR_ssh_private_path
# Forward the port 8443 (for ORDS local installation)
ssh -L 8443:0.0.0.0:8443 -L 8080:0.0.0.0:8080 -o StrictHostKeyChecking=no -i $TF_VAR_ssh_private_path -J opc@$BASTION_IP opc@$DB_NODE_IP 
