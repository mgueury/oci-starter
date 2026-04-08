SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

. ./shared_compute.sh

TARGET_OKE="/tmp/oke"
mkdir -p $TARGET_OKE

file_replace_variables() {
  local file="$1"
  local temp_file=$(mktemp)

  echo "Replace variables in file: $1"
  while IFS= read -r line || [ -n "$line" ]; do  
    while [[ $line =~ (.*)##(.*)##(.*) ]]; do
      local var_name="${BASH_REMATCH[2]}"
      echo "- variable: ${var_name}"

      if [[ ${var_name} =~ OPTIONAL/(.*) ]]; then
         var_name2="${BASH_REMATCH[1]}"
         var_value="${!var_name2}"
         if [ "$var_value" == "" ]; then
            var_value="__NOT_USED__"
         fi
      else
        var_value="${!var_name}"       
        if [ "$var_value" == "" ]; then
            echo "ERROR: Environment variable '${var_name}' is not defined."
            error_exit
        fi
      fi
      line=${line/"##${var_name}##"/${var_value}}
    done

    echo "$line" >> "$temp_file"
  done < "$file"

  mv "$temp_file" "$file"
}

copy_replace_apply_target_oke() {
  filepath="$1"  
  filename="${filepath##*/}"
  echo "-- kubectl apply -- $filename --"
  cp $filepath $TARGET_OKE/${filename}
  file_replace_variables $TARGET_OKE/${filename}
  kubectl apply -f $TARGET_OKE/${filename}
}

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