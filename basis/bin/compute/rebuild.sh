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
    cd $HOME/app
    for APP_DIR in `app_dir_list`; do
        if [ -f $APP_DIR/Dockerfile ]; then
            APP_NAME=$(basename "${APP_DIR}")
            title "$APP_NAME: Build"
            ./build_${APP_NAME}.sh
            title "$APP_NAME: Deploy in OKE"
            if [ -f k8s.yaml ]; then
                copy_replace_apply_target_oke src/app/${APP_NAME}/k8s.yaml
            fi
            if [ -f k8s-ingress.yaml ]; then
                copy_replace_apply_target_oke src/app/${APP_NAME}/k8s-ingress.yaml
            fi
        fi  
    done
else 
    echo "rebuild.sh: TF_VAR_deploy_type: $TF_VAR_deploy_type is not supported. It requires terraform to reexecute."
fi