#!/usr/bin/env bash
# compute_install.sh 
#
# Init of a compute
#
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

export ARCH=`rpm --eval '%{_arch}'`
echo "ARCH=$ARCH"

# Shared Install Function
. ./shared_compute.sh

if ! grep -q "export LC_CTYPE" $HOME/.bashrc; then
    # Set VI and NANO in utf8
    echo "export LC_CTYPE=en_US.UTF-8" >> $HOME/.bashrc
    echo "shopt -s direxpand" >> $HOME/.bashrc

    # Disable SELinux
    # XXXXXX Since OL8, the service does not start if SELINUX=enforcing XXXXXX
    sudo setenforce 0
    sudo sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config

    # Resize the boot volume (if >47GB)
    sudo /usr/libexec/oci-growfs -y

    # Build_host = bastion
    if [ "$TF_VAR_build_host" == "bastion" ]; then 
        # Kubernetes
        if [ "$TF_VAR_deploy_type" == "kubernetes" ]; then 
            install_docker_tools
            echo "export KUBECONFIG=$HOME/compute/kubeconfig_starter" >> $HOME/.bashrc
        fi 
        # Java 
        if [ "$TF_VAR_language" == "java" ]; then
            install_java
        fi
    fi


fi

# -- App --------------------------------------------------------------------
# Application Specific installation
# Build all app* directories
cd $HOME

for APP_DIR in `app_dir_list`; do
    if [ -f $APP_DIR/install.sh ]; then
        title "$APP_DIR: Install"
        if [ -f ${APP_DIR}/env.sh ]; then
            chmod +x ${APP_DIR}/env.sh
        fi
        if [ -f ${APP_DIR}/install.sh ]; then
            chmod +x ${APP_DIR}/install.sh
            ${APP_DIR}/install.sh
        fi
    fi  
done

# -- app/start*.sh -----------------------------------------------------------
for APP_DIR in `app_dir_list`; do
  # if [ -f $APP_DIR/restart.sh ]; then
  #  echo "$APP_DIR/restart.sh exists already"
  # else
    rm -f $APP_DIR/restart.sh 
    for START_SH in `ls $APP_DIR/start*.sh 2>/dev/null | sort -g`; do
      title "$START_SH"
      if [[ "$START_SH" =~ start_(.*).sh ]]; then
        APP_NAME=$(echo "$START_SH" | sed -E 's/(.*)\/start_([a-zA-Z0-9_]+)\.sh$/\1_\2/')
      elif [[ "$START_SH" =~ app/(.*)/start.sh ]]; then
        APP_NAME=$(echo "$START_SH" | sed -E 's/(.*)\/([a-zA-Z0-9_]+)\/start\.sh$/\1_\2/')
      else
        APP_NAME=${APP_DIR}
      fi
      echo "APP_NAME=$APP_NAME"
      # Hardcode the connection to the DB in the start.sh
      if [ "$DB_URL" != "" ]; then
        sed -i "s!##JDBC_URL##!$JDBC_URL!" $START_SH 
        sed -i "s!##DB_URL##!$DB_URL!" $START_SH 
      fi  
      sed -i "s!##TF_VAR_java_vm##!$TF_VAR_java_vm!" $START_SH
      chmod +x $START_SH

      # Create an "app.service" that starts when the machine starts.
      cat > /tmp/$APP_NAME.service << EOT
[Unit]
Description=App
After=network.target

[Service]
Type=simple
ExecStart=/home/opc/$START_SH
TimeoutStartSec=0
User=opc

[Install]
WantedBy=default.target
EOT
      sudo cp /tmp/$APP_NAME.service /etc/systemd/system
      sudo chmod 664 /etc/systemd/system/$APP_NAME.service
      sudo systemctl daemon-reload
      sudo systemctl enable $APP_NAME.service
      echo "sudo systemctl restart $APP_NAME" >> $APP_DIR/restart.sh 
    done  
  # fi  
  if [ -f $APP_DIR/restart.sh ]; then
    chmod +x $APP_DIR/restart.sh  
    $APP_DIR/restart.sh
  fi
done 

# -- Helper --------------------------------------------------------------------
cd $SCRIPT_DIR
mv helper.sh $HOME

