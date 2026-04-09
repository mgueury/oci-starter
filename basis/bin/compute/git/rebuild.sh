SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. ./shared_compute.sh

TARGET_OKE="$HOME/target/oke"
mkdir -p $TARGET_OKE


if [ "$TF_VAR_deploy_type" == "kubernetes" ] ; then 
    docker_login
fi

for APP_DIR in `app_dir_list`; do
    title "$APP_DIR"
    if [ -f $APP_DIR/install.sh ]; then
        APP_NAME=$(basename "${APP_DIR}")
        if [ -f build_${APP_NAME}.sh]; then
            title "$APP_NAME: Build"
            ./build_${APP_NAME}.sh
        fi
        if is_deploy_compute; then
            if [ -f ${APP_DIR}/restart.sh ]; then
                title "$APP_NAME: Restart"
                ${APP_DIR}/restart.sh
            fi
        elif [ "$TF_VAR_deploy_type" != "kubernetes" ] ; then 
            echo "rebuild.sh: TF_VAR_deploy_type: $TF_VAR_deploy_type is not supported. It requires terraform to redeploy."
        fi
    fi  
done
