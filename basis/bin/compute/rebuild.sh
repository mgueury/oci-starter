SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. ./shared_compute.sh

TARGET_OKE="$HOME/target/oke"
mkdir -p $TARGET_OKE

cd $HOME/app

if [ "$TF_VAR_deploy_type" == "kubernetes" ] ; then 
    docker_login
fi

for APP_DIR in `app_dir_list`; do
    if [ -f $APP_DIR/install.sh ]; then
        APP_NAME=$(basename "${APP_DIR}")
        if [ -f build_${APP_NAME}.sh]; then
            title "$APP_NAME: Build"
            ./build_${APP_NAME}.sh
        fi
        if [ "$TF_VAR_deploy_type" == "public_compute" ] || [ "$TF_VAR_deploy_type" == "private_compute" ] || [ "$TF_VAR_deploy_type" == "instance_pool" ]; then
            if [ -f ${APP_DIR}/restart.sh ]; then
                title "$APP_NAME: Restart"
                ${APP_DIR}/restart.sh
            fi
        elif [ "$TF_VAR_deploy_type" == "kubernetes" ] ; then 
            title "$APP_NAME: Pushing to OCIR"
            ocir_docker_push_app $APP_NAME
            title "$APP_NAME: Deploy in OKE"
            if [ -f k8s.yaml ]; then
                copy_replace_apply_target_oke src/app/${APP_NAME}/k8s.yaml
            fi
            if [ -f k8s-ingress.yaml ]; then
                copy_replace_apply_target_oke src/app/${APP_NAME}/k8s-ingress.yaml
            fi
        else 
            echo "rebuild.sh: TF_VAR_deploy_type: $TF_VAR_deploy_type is not supported. It requires terraform to redeploy."
        fi
    fi  
done
