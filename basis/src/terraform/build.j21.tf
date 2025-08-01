{%- if infra_as_code == "from_resource_manager" %}
variable project_dir { default="." }
{%- else %}
variable project_dir { default="../.." }
{%- endif %}

## BUILD_DEPLOY
resource "null_resource" "build_deploy" {
  provisioner "local-exec" {
    command = <<-EOT
{%- for key in terraform_locals %}
        export {{key.upper()}}="${local.local_{{key}}}"
{%- endfor %}     
        cd ${var.project_dir}
        # pwd
        # ls -al target
        # cat target/terraform.tfstate
        # export
        export CALLED_BY_TERRAFORM="true"
        . ./starter.sh env
        # Run config command on the DB directly (ex RAC)
{%- if db_subtype == "rac" %}
        src/db/deploy_rac.sh
        exit_on_error "Deploy RAC"
{%- elif db_type == "db_free" %} 
        src/db/deploy_db_free.sh
        exit_on_error "Deploy DB Free"
{%- elif db_type == "mysql" and deploy_type == "public_compute" %} 
        src/db/deploy_mysql_public_compute.sh
        exit_on_error "Deploy MySQL Public Compute"
{%- elif db_type == "database" and language == "apex" %} 
        src/db/deploy_apex_database.sh
        exit_on_error "Deploy APEX Database"
{%- endif %}

        # Build the DB tables (via Bastion)
        if [ -d src/db ]; then
            title "Deploy Bastion"
            $BIN_DIR/deploy_bastion.sh
            exit_on_error "Deploy Bastion"   
        fi  

        # Init target/compute
        if is_deploy_compute; then
            mkdir -p target/compute
            cp -r src/compute target/compute/.
        fi

        # Build all app* directories
        for APP_DIR in `app_dir_list`; do
            title "Build App $APP_DIR"
            src/$APP_DIR/build_app.sh
            exit_on_error "Build App $APP_DIR"
        done

        if [ -f src/ui/build_ui.sh ]; then
            title "Build UI"
            src/ui/build_ui.sh 
            exit_on_error "Build UI"
        fi

        # Deploy
        title "Deploy $TF_VAR_deploy_type"
        if is_deploy_compute; then
            $BIN_DIR/deploy_compute.sh
            exit_on_error "Deploy $TF_VAR_deploy_type"
        elif [ "$TF_VAR_deploy_type" == "kubernetes" ]; then
            $BIN_DIR/deploy_oke.sh
            exit_on_error "Deploy $TF_VAR_deploy_type"
        elif [ "$TF_VAR_deploy_type" == "container_instance" ]; then
            $BIN_DIR/deploy_ci.sh
            exit_on_error "Deploy $TF_VAR_deploy_type"
        fi
        ./starter.sh frm
        EOT
  }
  depends_on = [
{%- for key in terraform_resources %}
    {{key}},
{%- endfor %}    
  ]

  triggers = {
    always_run = "${timestamp()}"
  }      
}

{%- if terraform_resources_part2|length>0 %}
# PART2
#
# In case like instance_pool, oke, function, container_instance, ...
# More terraform resources need to be created after build_deploy.
# Reread the env viables
data "external" "env_part2" {
  program = ["cat", "${var.project_dir}/target/resource_manager_variables.json"]
  depends_on = [
    null_resource.build_deploy
  ]
}
{%- endif %}

## AFTER_BUILD
# Last action at the end of the build
resource "null_resource" "after_build" {
  provisioner "local-exec" {
    command = <<-EOT
{%- for key in terraform_locals %}
        export {{key.upper()}}="${local.local_{{key}}}"
{%- endfor %}     
        cd ${var.project_dir}    
        . ./starter.sh env    
        if [ "$TF_VAR_tls" != "" ]; then
            title "Certificate - Post Deploy"
            certificate_post_deploy 
        fi

        $BIN_DIR/add_api_portal.sh

        # Custom code after build
        if [ -f $PROJECT_DIR/src/after_build.sh ]; then
            $PROJECT_DIR/src/after_build.sh
        fi
        title "Done"
        $BIN_DIR/done.sh          
        EOT
  }
  depends_on = [
{%- for key in terraform_resources_part2 %}
    {{key}},
{%- endfor %}      
    null_resource.build_deploy
  ]

  triggers = {
    always_run = "${timestamp()}"
  }    
}

# BEFORE_DESTROY
resource "null_resource" "before_destroy" {
  provisioner "local-exec" {
      when = destroy
      command = <<-EOT
        if [ ! -f starter.sh ]; then 
          cd ../..
        fi
        ./starter.sh destroy --called_by_resource_manager
        EOT
  }

  depends_on = [  
    null_resource.after_build
  ]
}
