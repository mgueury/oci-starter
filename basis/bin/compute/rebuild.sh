SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. ./shared_compute.sh

TARGET_OKE="$HOME/target/oke"
mkdir -p $TARGET_OKE


if [ "$TF_VAR_deploy_type" == "kubernetes" ] ; then 
    docker_login
fi

cd $HOME/app
chmod +x */*.sh

for APP_DIR in `app_dir_list`; do
    APP_NAME=$(basename "${APP_DIR}")
    title "$APP_NAME"
    if [ -f build_${APP_NAME}.sh ]; then
        # Build in bastion
        title "$APP_NAME: Build"
        ./build_${APP_NAME}.sh
    elif [ "APP_NAME" == "db" ] then
        # Database
        title "$APP_NAME: Install"
        ${APP_DIR}/install.sh
    elif [ -f $APP_DIR/install.sh ] && is_deploy_compute; then
        # Build in terraform - compute 
        title "$APP_NAME: Install"
        ${APP_DIR}/install.sh
    fi
    if is_deploy_compute; then
        if [ -f ${APP_DIR}/restart.sh ]; then
            title "$APP_NAME: Restart"
            ${APP_DIR}/restart.sh
        fi
    elif [ "$TF_VAR_deploy_type" != "kubernetes" ] ; then 
        echo "rebuild.sh: TF_VAR_deploy_type: $TF_VAR_deploy_type is not supported. It requires terraform to redeploy."
    fi
done
