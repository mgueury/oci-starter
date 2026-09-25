###############################################################################
# REST hosted application
###############################################################################

resource "oci_generative_ai_hosted_application" "starter_rest_hosted_application" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-rest-hosted-app"

  ###########################################################################
  # Same environment variables as the old "rest" container
  ###########################################################################

{%- if db_type != "none" %}
  environment_variables {
    name  = "JDBC_URL"
    type  = "PLAINTEXT"
    value = jsonencode(local.local_jdbc_url)
  }

  environment_variables {
    name  = "DB_USER"
    type  = "PLAINTEXT"
    value = jsonencode(var.db_user != null ? var.db_user : "{{ db_user }}")
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
{%- endif %}

{%- if db_type == "nosql" %}
  environment_variables {
    name  = "TF_VAR_compartment_ocid"
    type  = "PLAINTEXT"
    value = jsonencode(var.compartment_ocid)
  }

  environment_variables {
    name  = "TF_VAR_nosql_endpoint"
    type  = "PLAINTEXT"
    value = jsonencode("nosql.${var.region}.oci.oraclecloud.com")
  }
{%- endif %}

{%- if python_framework in [ "langgraph", "responses" ] %}
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
{%- endif %}

{%- if python_framework == "langgraph" %}
  environment_variables {
    name  = "MCP_SERVER_URL"
    type  = "PLAINTEXT"
    value = jsonencode("${local.hosted_mcp_invoke_url}/mcp")
  }
{%- elif python_framework == "responses" %}
  environment_variables {
    name  = "MCP_SERVER_URL"
    type  = "PLAINTEXT"
    value = jsonencode("${local.hosted_mcp_invoke_url}/mcp")
  }
{%- endif %}

  ###########################################################################
  # Authentication
  ###########################################################################

  inbound_auth_config {
    inbound_auth_config_type = "NO_AUTH_CONFIG"

    # idcs_config {
    #   domain_url = var.hosted_app_idcs_domain_url
    #   scope      = var.hosted_app_idcs_scope
    #   audience   = var.hosted_app_idcs_audience
    # }
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
    scaling_type        = "CPU"
    min_replica         = 1
    max_replica         = 1
    target_cpu_threshold = 50
  }



  # The CLI preserves the Terraform bootstrap variables and updates DB_URL and
  # JDBC_URL after each image build. Terraform must not overwrite those values.
  lifecycle {
    ignore_changes = [environment_variables]
  }

  freeform_tags = local.freeform_tags
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

{%- if python_framework in [ "langgraph", "responses" ] %}

resource "oci_generative_ai_hosted_application" "starter_mcp_hosted_application" {
  compartment_id = local.lz_app_cmp_ocid
  display_name   = "${var.prefix}-mcp-hosted-app"

{%- if db_type != "none" %}
  environment_variables {
    name  = "DB_URL"
    type  = "PLAINTEXT"
    value = jsonencode(local.local_db_url)
  }

  environment_variables {
    name  = "JDBC_URL"
    type  = "PLAINTEXT"
    value = jsonencode(local.local_jdbc_url)
  }

  environment_variables {
    name  = "DB_USER"
    type  = "PLAINTEXT"
    value = jsonencode(var.db_user != null ? var.db_user : "{{ db_user }}")
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
{%- endif %}

{%- if db_type == "nosql" %}
  environment_variables {
    name  = "TF_VAR_compartment_ocid"
    type  = "PLAINTEXT"
    value = jsonencode(var.compartment_ocid)
  }

  environment_variables {
    name  = "TF_VAR_nosql_endpoint"
    type  = "PLAINTEXT"
    value = jsonencode("nosql.${var.region}.oci.oraclecloud.com")
  }
{%- endif %}

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



  # DB_URL and JDBC_URL are maintained by bin/hosted_app_cli.sh after each
  # image build. Terraform must not overwrite the SDK-managed values.
  lifecycle {
    ignore_changes = [environment_variables]
  }

  freeform_tags = local.freeform_tags
}

{%- endif %}


###############################################################################
# Hosted application invoke URLs
#
# Equivalent to the old Container Instance private IP destinations.
###############################################################################

locals {
  hosted_application_base_url = "https://inference.generativeai.${var.region}.oci.oraclecloud.com/20251112/hostedApplications"

  hosted_rest_invoke_url = "${local.hosted_application_base_url}/${oci_generative_ai_hosted_application.starter_rest_hosted_application.id}/actions/invoke"

  hosted_ui_invoke_url = "${local.hosted_application_base_url}/${oci_generative_ai_hosted_application.starter_ui_hosted_application.id}/actions/invoke"

{%- if python_framework in [ "langgraph", "responses" ] %}
  hosted_mcp_invoke_url = "${local.hosted_application_base_url}/${oci_generative_ai_hosted_application.starter_mcp_hosted_application.id}/actions/invoke"
{%- endif %}
}


###############################################################################
# API Gateway
###############################################################################

resource "oci_apigateway_deployment" "starter_apigw_deployment" {
{%- if tls is defined %}
  count = var.certificate_ocid == null ? 0 : 1
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

{%- if python_framework in [ "langgraph", "responses" ] %}

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

{%- endif %}

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
}


###############################################################################
# Hosted Application service logs
#
# The log group is Terraform-managed. Each service log is bound to its Hosted
# Application, so Terraform recreates it if that application is replaced.
###############################################################################

resource "oci_logging_log" "starter_rest_hosted_app_log" {
  display_name = "${var.prefix}-rest-hosted-app_genai-hosted-deployment-log"
  log_group_id = oci_logging_log_group.starter_log_group.id
  log_type     = "SERVICE"
  is_enabled   = true

  configuration {
    compartment_id = local.lz_app_cmp_ocid

    source {
      category    = "genai-hosted-deployment-log"
      resource    = oci_generative_ai_hosted_application.starter_rest_hosted_application.id
      service     = "genai-hosted-deployment-prod"
      source_type = "OCISERVICE"
    }
  }
}


resource "oci_logging_log" "starter_ui_hosted_app_log" {
  display_name = "${var.prefix}-ui-hosted-app_genai-hosted-deployment-log"
  log_group_id = oci_logging_log_group.starter_log_group.id
  log_type     = "SERVICE"
  is_enabled   = true

  configuration {
    compartment_id = local.lz_app_cmp_ocid

    source {
      category    = "genai-hosted-deployment-log"
      resource    = oci_generative_ai_hosted_application.starter_ui_hosted_application.id
      service     = "genai-hosted-deployment-prod"
      source_type = "OCISERVICE"
    }
  }
}

{%- if python_framework in [ "langgraph", "responses" ] %}

resource "oci_logging_log" "starter_mcp_hosted_app_log" {
  display_name = "${var.prefix}-mcp-hosted-app_genai-hosted-deployment-log"
  log_group_id = oci_logging_log_group.starter_log_group.id
  log_type     = "SERVICE"
  is_enabled   = true

  configuration {
    compartment_id = local.lz_app_cmp_ocid

    source {
      category    = "genai-hosted-deployment-log"
      resource    = oci_generative_ai_hosted_application.starter_mcp_hosted_application.id
      service     = "genai-hosted-deployment-prod"
      source_type = "OCISERVICE"
    }
  }
}

{%- endif %}