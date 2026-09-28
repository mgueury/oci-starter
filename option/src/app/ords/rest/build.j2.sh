{% import "build.j2_macro" as m with context %}
{{ m.build_common() }}

if is_deploy_compute; then
    echo "Nothing to deploy on compute"
elif [ "$TF_VAR_deploy_type" == "kubernetes" ]; then
    # This app has no image: deploy its ExternalName service and ORDS route.
    oke_deploy_app "$APP_NAME"
else
    echo "No docker build needed."
fi  
