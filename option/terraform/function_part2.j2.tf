{%- if language == "python" %}
# OCI Function - Archive (zip file)
variable "function_runtime_name" {
  type        = string
  default     = "python312.ol9"
  description = "OCI managed runtime name for the code-only Function."
}

variable "function_handler" {
  type        = string
  default     = "func.handler"
  description = "Function handler; leave empty for Go."
}

data "local_file" "starter_fn_archive" {
  filename   = "${local.project_dir}/target/function.zip"
  depends_on = [null_resource.build_deploy]
}
{%- else %}
# OCI Function - Container (Docker file)
locals {
  fn_image=data.external.env_part2.result.fn_image
}
{%- endif %}

resource "oci_functions_function" "starter_fn_function" {
  #Required
  application_id = local.fnapp_ocid
  display_name   = "${var.prefix}-fn-function"
  memory_in_mbs  = "2048"
{%- if language == "python" %}  
  source_details {
    source_type = "ARCHIVE"
    archive_source_details {
      archive_source_type = "DIRECT_ARCHIVE"
      archive_file        = data.local_file.starter_fn_archive.content_base64
    }
    handler = var.function_handler != "" ? var.function_handler : null
    runtime_config {
      runtime_config_type    = "FUNCTION_UPDATE"
      functions_runtime_name = var.function_runtime_name
    }
  }
{%- else %}  
  source_details {
    source_type = "CONTAINER_IMAGE"
    image = local.fn_image
  }
{%- endif %}  
  config = {
    {%- if db_family != "none" %}
    {%- if language == "java" %} 
    JDBC_URL      = local.local_jdbc_url,
    {%- else %}     
    DB_URL      = local.local_db_url,
    {%- endif %}     
    DB_USER     = var.db_user != null ? var.db_user : "{{ db_user }}",
    DB_PASSWORD = var.db_password,
    {%- endif %}     
    {%- if db_type == "nosql" %} 
    TF_VAR_compartment_ocid = var.compartment_ocid,
    # XXX Ideally it should be nosql.${region}.oci.${regionDomain}  
    TF_VAR_nosql_endpoint = "nosql.${var.region}.oci.oraclecloud.com",
    {%- endif %}     
  }
  #Optional
  timeout_in_seconds = "300"
  trace_config {
    is_enabled = true
  }


  freeform_tags = local.freeform_tags
/*
  # To start faster
  provisioned_concurrency_config {
    strategy = "CONSTANT"
    count = 40
  }
*/    
   depends_on = [ local.fn_image ]
}

resource "oci_apigateway_deployment" "starter_apigw_deployment" {
{%- if tls is defined %}
  count = (local.fn_image == null || var.certificate_ocid == null) ? 0 : 1
{%- endif %}   
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-apigw-deployment"
  gateway_id     = local.apigw_ocid
  path_prefix    = "/${var.prefix}"
  specification {
    logging_policies {
      access_log {
        is_enabled = true
      }
      execution_log {
        #Optional
        is_enabled = true
      }
    }
    routes {
      path    = "/app/dept"
      methods = [ "ANY" ]
      backend {
        type = "ORACLE_FUNCTIONS_BACKEND"
        function_id   = oci_functions_function.starter_fn_function.id
      }
    }    
    routes {
      path    = "/app/info"
      methods = [ "ANY" ]
      backend {
        type = "STOCK_RESPONSE_BACKEND"
        body   = "{{ deploy_name }} - {{ dbName }} - {{ language }} - {{ ui_name }}"
        status = 200
      }
    }    
    routes {
      path    = "/"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "${local.bucket_url}/index.html"
        connect_timeout_in_seconds = 10
        read_timeout_in_seconds = 30
        send_timeout_in_seconds = 30
      }
    }    
    routes {
      path    = "/{pathname*}"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "${local.bucket_url}/$${request.path[pathname]}"
      }
    }
  }
  freeform_tags = local.api_tags

  depends_on = [ local.fn_image ]
}