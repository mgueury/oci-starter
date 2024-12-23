
{%- if language == "apex" %}
locals {
  db_root_url = replace(data.oci_database_autonomous_database.starter_atp.connection_urls[0].apex_url, "/ords/apex", "" )
}
{%- else %}
# Used for APIGW and TAGS
locals {
  apigw_dest_private_ip = local.compute_private_ip
}
{%- endif %}

{%- if language == "apex" %}

# One single entry "/" would work too. 
# The reason of the 3 entries is to allow to make it work when the APIGW is shared with other URLs (ex: testsuite)
resource "oci_apigateway_deployment" "starter_apigw_deployment_ords" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-apigw-deployment"
  gateway_id     = local.apigw_ocid
  path_prefix    = "/ords"
  specification {
    # Go directly from APIGW to APEX in the DB    
    routes {
      path    = "/{pathname*}"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "${local.db_root_url}/ords/$${request.path[pathname]}"
        connect_timeout_in_seconds = 60
        read_timeout_in_seconds = 120
        send_timeout_in_seconds = 120            
      }
      request_policies {
        header_transformations {
          set_headers {
            items {
              name = "Host"
              values = ["$${request.headers[Host]}"]
            }
          }
        }
      }
    }
  }
  freeform_tags = local.api_tags
}

resource "oci_apigateway_deployment" "starter_apigw_deployment_i" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-apigw-deployment"
  gateway_id     = local.apigw_ocid
  path_prefix    = "/i"
  specification {
    # Go directly from APIGW to APEX in the DB    
    routes {
      path    = "/{pathname*}"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "${local.db_root_url}/i/$${request.path[pathname]}"
        connect_timeout_in_seconds = 60
        read_timeout_in_seconds = 120
        send_timeout_in_seconds = 120            
      }
      request_policies {
        header_transformations {
          set_headers {
            items {
              name = "Host"
              values = ["$${request.headers[Host]}"]
            }
          }
        }
      }
    }
  }
  freeform_tags = local.api_tags
}

resource "oci_apigateway_deployment" "starter_apigw_deployment_app" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-apigw-deployment"
  gateway_id     = local.apigw_ocid
  path_prefix    ="/${var.prefix}"
  specification {
    # Go directly from APIGW to APEX in the DB    
    routes {
      path    = "/{pathname*}"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "${local.db_root_url}/ords/r/apex_app/apex_app"
        connect_timeout_in_seconds = 60
        read_timeout_in_seconds = 120
        send_timeout_in_seconds = 120            
      }
      request_policies {
        header_transformations {
          set_headers {
            items {
              name = "Host"
              values = ["$${request.headers[Host]}"]
            }
          }
        }
      }
    }
  }
  freeform_tags = local.api_tags
}   


{%- else %}
resource "oci_apigateway_deployment" "starter_apigw_deployment" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-apigw-deployment"
  gateway_id     = local.apigw_ocid
  path_prefix    = "/${var.prefix}"
  specification {
    # Route the COMPUTE_PRIVATE_IP 
    routes {
      path    = "/app/{pathname*}"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "##APP_URL##"
      }
    } 
    routes {
      path    = "/{pathname*}"
      methods = [ "ANY" ]
      backend {
        type = "HTTP_BACKEND"
        url    = "http://${local.apigw_dest_private_ip}/$${request.path[pathname]}"
      }
    }    
  }
  freeform_tags = local.api_tags
}    
{%- endif %}      

/*
resource oci_logging_log starter_apigw_deployment_execution {
  count = var.log_group_ocid == "" ? 0 : 1
  log_group_id = var.log_group_ocid
  configuration {
    compartment_id = local.lz_app_cmp_ocid
    source {
      category    = "execution"
      resource    = oci_apigateway_deployment.starter_apigw_deployment.id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }
  }
  display_name = "${var.prefix}-apigw-deployment-execution"
  freeform_tags = local.freeform_tags
  is_enabled         = "true"
  log_type           = "SERVICE"
  retention_duration = "30"
}

resource oci_logging_log starter_apigw_deployment_access {
  count = var.log_group_ocid == "" ? 0 : 1
  log_group_id = var.log_group_ocid
  configuration {
    compartment_id = local.lz_app_cmp_ocid
    source {
      category    = "access"
      resource    = oci_apigateway_deployment.starter_apigw_deployment.id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }
  }
  display_name = "${var.prefix}-apigw-deployment-access"
  freeform_tags = local.freeform_tags
  is_enabled         = "true"
  log_type           = "SERVICE"
  retention_duration = "30"
}
*/