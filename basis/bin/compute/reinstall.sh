SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. ./shared_compute.sh

TARGET_OKE="/tmp/oke"
mkdir -p $TARGET_OKE

if [ "$TF_VAR_deploy_type" == "public_compute" ] || [ "$TF_VAR_deploy_type" == "private_compute" ] || [ "$TF_VAR_deploy_type" == "instance_pool" ]; then
    for APP_DIR in `app_dir_list`; do
        if [ -f $APP_DIR/install.sh ]; then
            title "$APP_DIR: Install"
            ${APP_DIR}/install.sh
            if [ -f ${APP_DIR}/restart.sh ]; then
                ${APP_DIR}/restart.sh
            fi
        fi  
    done
elif [ "$TF_VAR_deploy_type" == "kubernetes" ] ; then 
    for APP_DIR in `app_dir_list`; do
        if [ -f $APP_DIR/docker.sh ]; then
            title "$APP_DIR: Docker build"
            cd ${APP_DIR}
            APP_NAME=APP_NAME=$(basename "${APP_DIR}")
            docker image rm ${TF_VAR_prefix}-${APP_NAME}:latest
            docker build -t ${TF_VAR_prefix}-${APP_NAME}:latest .
            if [ -f k8s.yaml ]; then
                copy_replace_apply_target_oke src/app/${APP_NAME}/k8s.yaml
            fi
            if [ -f k8s-ingress.yaml ]; then
                copy_replace_apply_target_oke src/app/${APP_NAME}/k8s-ingress.yaml
            fi
            cd -
        fi  
    done
else 
    echo "rebuild.sh: TF_VAR_deploy_type: $TF_VAR_deploy_type is not supported. It requires terraform to reexecute."
fi