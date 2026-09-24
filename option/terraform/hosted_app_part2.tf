###############################################################################
# REST hosted application
###############################################################################

resource "oci_generative_ai_hosted_application" "starter_rest_hosted_application" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-rest-hosted-app"

  environment_variables {
    name  = "DB_USER"
    type  = "PLAINTEXT"
    value = jsonencode(var.db_user != null ? var.db_user : "admin")
  }

  environment_variables {
    name  = "DB_PASSWORD"
    type  = "PLAINTEXT"
    value = jsonencode(var.db_password)
  }

  environment_variables {
    name  = "JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL"
    type  = "PLAINTEXT"
    value = jsonencode(local.local_jdbc_url)
  }
  environment_variables {
    name  = "TF_VAR_region"
    type  = "PLAINTEXT"
    value = jsonencode(var.region)
  }

  environment_variables {
    name  = "TF_VAR_compartment_ocid"
    type  = "PLAINTEXT"
    value = jsonencode(var.compartment_ocid)
  }

  environment_variables {
    name  = "TF_VAR_project_ocid"
    type  = "PLAINTEXT"
    value = jsonencode(local.local_project_ocid)
  }

  environment_variables {
    name  = "AUTH_TYPE"
    type  = "PLAINTEXT"
    value = jsonencode("RESOURCE_PRINCIPAL")
  }

  environment_variables {
    name  = "MCP_SERVER_URL"
    type  = "PLAINTEXT"
    value = jsonencode("${local.hosted_mcp_invoke_url}/mcp")
  }

  ###########################################################################
  # Authentication
  ###########################################################################

  inbound_auth_config {
    inbound_auth_config_type = "NO_AUTH_CONFIG"
  }

  ###########################################################################
  # Networking
  #
  # CUSTOM outbound networking replaces the old Container Instance VNIC
  # behavior and permits access through the application subnet.
  ###########################################################################

  networking_config {
    inbound_networking_config {
      endpoint_mode = "PUBLIC"
    }

    outbound_networking_config {
      network_mode     = "CUSTOM"
      custom_subnet_id = data.oci_core_subnet.starter_app_subnet.id
    }
  }

  ###########################################################################
  # Approximation of one always-running Container Instance
  ###########################################################################

  scaling_config {
    scaling_type         = "CPU"
    min_replica          = 1
    max_replica          = 1
    target_cpu_threshold = 50
  }

  freeform_tags = local.freeform_tags

  # The CLI preserves the Terraform bootstrap variables and updates DB_URL and
  # JDBC_URL after each image build. Terraform must not overwrite those values.
  lifecycle {
    ignore_changes = [environment_variables]
  }
}


###############################################################################
# UI hosted application
###############################################################################

resource "oci_generative_ai_hosted_application" "starter_ui_hosted_application" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-ui-hosted-app"

  inbound_auth_config {
    inbound_auth_config_type = "NO_AUTH_CONFIG"
  }

  networking_config {
    inbound_networking_config {
      endpoint_mode = "PUBLIC"
    }

    outbound_networking_config {
      network_mode     = "CUSTOM"
      custom_subnet_id = data.oci_core_subnet.starter_app_subnet.id
    }
  }

  scaling_config {
    scaling_type         = "CPU"
    min_replica          = 1
    max_replica          = 1
    target_cpu_threshold = 50
  }

  freeform_tags = local.freeform_tags
}


###############################################################################
# MCP hosted application/deployment
###############################################################################

resource "oci_generative_ai_hosted_application" "starter_mcp_hosted_application" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-mcp-hosted-app"
  environment_variables {
    name  = "DB_USER"
    type  = "PLAINTEXT"
    value = jsonencode(var.db_user != null ? var.db_user : "admin")
  }

  environment_variables {
    name  = "DB_PASSWORD"
    type  = "PLAINTEXT"
    value = jsonencode(var.db_password)
  }

  environment_variables {
    name  = "JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL"
    type  = "PLAINTEXT"
    value = jsonencode(local.local_jdbc_url)
  }

  inbound_auth_config {
    inbound_auth_config_type = "NO_AUTH_CONFIG"
  }

  networking_config {
    inbound_networking_config {
      endpoint_mode = "PUBLIC"
    }

    outbound_networking_config {
      network_mode     = "CUSTOM"
      custom_subnet_id = data.oci_core_subnet.starter_app_subnet.id
    }
  }

  scaling_config {
    scaling_type         = "CPU"
    min_replica          = 1
    max_replica          = 1
    target_cpu_threshold = 50
  }

  freeform_tags = local.freeform_tags

  # DB_URL and JDBC_URL are maintained by bin/hosted_app_cli.sh after each
  # image build. Terraform must not overwrite the SDK-managed values.
  lifecycle {
    ignore_changes = [environment_variables]
  }
}


###############################################################################
# Hosted application invoke URLs
#
# Equivalent to the old Container Instance private IP destinations.
###############################################################################

locals {
  hosted_application_base_url = "https://inference.generativeai.${var.region}.oci.oraclecloud.com/20251112/hostedApplications"

  hosted_rest_invoke_url = "${local.hosted_application_base_url}/${oci_generative_ai_hosted_application.starter_rest_hosted_application.id}/actions/invoke"

  hosted_ui_invoke_url  = "${local.hosted_application_base_url}/${oci_generative_ai_hosted_application.starter_ui_hosted_application.id}/actions/invoke"
  hosted_mcp_invoke_url = "${local.hosted_application_base_url}/${oci_generative_ai_hosted_application.starter_mcp_hosted_application.id}/actions/invoke"
}


###############################################################################
# API Gateway
###############################################################################

resource "oci_apigateway_deployment" "starter_apigw_deployment" {

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
        is_enabled = true
      }
    }

    #########################################################################
    # REST
    #
    # Old:
    # /app/* -> REST container
    #
    # New:
    # /app/* -> REST hosted application
    #########################################################################

    routes {
      path    = "/app/{pathname*}"
      methods = ["ANY"]

      backend {
        type = "HTTP_BACKEND"
        url  = "${local.hosted_rest_invoke_url}/$${request.path[pathname]}"
      }
    }

    #########################################################################
    # MCP
    #
    # Old:
    # http://<container-private-ip>:2025/*
    #
    # New:
    # Hosted MCP application /*
    #########################################################################

    routes {
      path    = "/mcp_server/{pathname*}"
      methods = ["ANY"]

      backend {
        type = "HTTP_BACKEND"
        url  = "${local.hosted_mcp_invoke_url}/$${request.path[pathname]}"
      }
    }

    #########################################################################
    # UI
    #
    # Old:
    # http://<container-private-ip>/*
    #
    # New:
    # UI hosted application /*
    #########################################################################

    routes {
      path    = "/{pathname*}"
      methods = ["ANY"]

      backend {
        type = "HTTP_BACKEND"
        url  = "${local.hosted_ui_invoke_url}/$${request.path[pathname]}"
      }
    }
  }

  freeform_tags = local.api_tags

  depends_on = [null_resource.build_deploy]
}

###############################################################################
# Handoff from Terraform to the OCI SDK
#
# Existing deployments are removed from state without deletion. New and existing
# deployments are subsequently created or updated by bin/hosted_app_cli.sh.
###############################################################################

removed {
  from = oci_generative_ai_hosted_deployment.starter_rest_hosted_deployment
  lifecycle { destroy = false }
}

removed {
  from = oci_generative_ai_hosted_deployment.starter_ui_hosted_deployment
  lifecycle { destroy = false }
}

removed {
  from = oci_generative_ai_hosted_deployment.starter_mcp_hosted_deployment
  lifecycle { destroy = false }
}
