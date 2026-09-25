#!/usr/bin/env bash
# Synchronize OCI Generative AI Hosted Deployments after an image build.

set -euo pipefail

APP_SUFFIX=""
IMAGE=""
CONTAINER_URI=""
IMAGE_TAG=""
TEMP_DIR=""

usage() {
    echo "Usage: $0 --app {rest|ui|mcp_server} --image <fully-qualified-image:tag>" >&2
}

error() {
    echo "ERROR: $*" >&2
    exit 1
}

require_environment() {
    local name=$1
    [ -n "${!name:-}" ] || error "$name must be set before synchronizing a hosted application"
}

oci_genai() {
    oci --region "$TF_VAR_region" generative-ai "$@"
}

cleanup() {
    [ -n "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

parse_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --app)
                [ "$#" -ge 2 ] || error "--app requires a value"
                case "$2" in
                    rest|ui) APP_SUFFIX=$2 ;;
                    mcp_server) APP_SUFFIX=mcp ;;
                    *) error "Unsupported hosted application: $2" ;;
                esac
                shift 2
                ;;
            --image)
                [ "$#" -ge 2 ] || error "--image requires a value"
                IMAGE=$2
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown argument: $1"
                ;;
        esac
    done

    [ -n "$APP_SUFFIX" ] || error "--app is required"
    [ -n "$IMAGE" ] || error "--image is required"
}

split_image() {
    CONTAINER_URI=${IMAGE%:*}
    IMAGE_TAG=${IMAGE##*:}
    [ "$CONTAINER_URI" != "$IMAGE" ] && [ -n "$CONTAINER_URI" ] && [ -n "$IMAGE_TAG" ] \
        || error "Expected a fully-qualified, tagged container image; got $IMAGE"
}

single_active_id() {
    local json=$1
    local description=$2
    local ids
    ids=$(jq -er '
        [.data.items[]?
         | select((.["lifecycle-state"] // .lifecycleState) != "DELETED"
                  and (.["lifecycle-state"] // .lifecycleState) != "DELETING")
         | .id]
        | if length == 1 then .[0]
          elif length == 0 then empty
          else error("multiple active resources")
          end
    ' <<<"$json") || error "Expected exactly one $description"
    [ -n "$ids" ] || error "Expected exactly one $description; found none"
    printf '%s\n' "$ids"
}

deployment_id_or_empty() {
    local json=$1
    jq -er '
        [.data.items[]?
         | select((.["lifecycle-state"] // .lifecycleState) != "DELETED"
                  and (.["lifecycle-state"] // .lifecycleState) != "DELETING")
         | .id]
        | if length == 0 then ""
          elif length == 1 then .[0]
          else error("multiple active resources")
          end
    ' <<<"$json" || error "Expected at most one active Hosted Deployment"
}

merge_runtime_environment() {
    local application_json=$1
    jq --arg db_url "$DB_URL" --arg jdbc_url "$JDBC_URL" --arg javax_sql_datasource_url "$JDBC_URL" --arg project_ocid "$PROJECT_OCID" --arg mcp_server_url "${MCP_SERVER_URL:-}" '
        def runtime_value($value): {
            name: $value.name,
            type: "PLAINTEXT",
            value: $value.value
        };
        (.data["environment-variables"] // .data.environmentVariables // []) as $variables
        | reduce $variables[] as $variable (
            {values: [], names: {}};
            if $variable.name == "DB_URL" then
                .values += [runtime_value({name: "DB_URL", value: $db_url})]
                | .names.DB_URL = true
            elif $variable.name == "JDBC_URL" then
                .values += [runtime_value({name: "JDBC_URL", value: $jdbc_url})]
                | .names.JDBC_URL = true
            elif $variable.name == "JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL" then
                .values += [runtime_value({name: "JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL", value: $javax_sql_datasource_url})]
                | .names.JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL = true
            elif $variable.name == "TF_VAR_project_ocid" then
                .values += [runtime_value({name: "TF_VAR_project_ocid", value: $project_ocid})]
                | .names.TF_VAR_project_ocid = true
            elif $variable.name == "MCP_SERVER_URL" and $mcp_server_url != "" then
                .values += [runtime_value({name: "MCP_SERVER_URL", value: $mcp_server_url})]
                | .names.MCP_SERVER_URL = true
            else
                .values += [$variable]
                | .names[$variable.name] = true
            end
        )
        | .values
          + (if .names.DB_URL then [] else [runtime_value({name: "DB_URL", value: $db_url})] end)
          + (if .names.JDBC_URL then [] else [runtime_value({name: "JDBC_URL", value: $jdbc_url})] end)
          + (if .names.JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL then [] else [runtime_value({name: "JAVAX_SQL_DATASOURCE_DS1_DATASOURCE_URL", value: $javax_sql_datasource_url})] end)
          + (if .names.TF_VAR_project_ocid then [] else [runtime_value({name: "TF_VAR_project_ocid", value: $project_ocid})] end)
          + (if $mcp_server_url == "" or .names.MCP_SERVER_URL then [] else [runtime_value({name: "MCP_SERVER_URL", value: $mcp_server_url})] end)
    ' <<<"$application_json"
}

main() {
    parse_arguments "$@"
    require_environment TF_VAR_compartment_ocid
    require_environment TF_VAR_prefix
    require_environment TF_VAR_region
    require_environment DB_URL
    require_environment JDBC_URL
    require_environment PROJECT_OCID
    command -v oci >/dev/null 2>&1 || error "OCI CLI not found"
    command -v jq >/dev/null 2>&1 || error "jq not found"
    split_image

    TEMP_DIR=$(mktemp -d /tmp/hosted-app-cli.XXXXXX)
    trap cleanup EXIT

    local display_name="${TF_VAR_prefix}-${APP_SUFFIX}-hosted-app"
    local applications application_id application_details mcp_applications mcp_application_id
    applications=$(oci_genai hosted-application-collection list-hosted-applications \
        --compartment-id "$TF_VAR_compartment_ocid" \
        --display-name "$display_name" \
        --all)
    application_id=$(single_active_id "$applications" "Hosted Application named $display_name")
    application_details=$(oci_genai hosted-application get \
        --hosted-application-id "$application_id")

    if [ "$APP_SUFFIX" = "rest" ] || [ "$APP_SUFFIX" = "mcp" ]; then
        if [ "$APP_SUFFIX" = "rest" ]; then
            mcp_applications=$(oci_genai hosted-application-collection list-hosted-applications \
                --compartment-id "$TF_VAR_compartment_ocid" \
                --display-name "${TF_VAR_prefix}-mcp-hosted-app" \
                --all)
            mcp_application_id=$(single_active_id "$mcp_applications" "Hosted Application named ${TF_VAR_prefix}-mcp-hosted-app")
            MCP_SERVER_URL="https://inference.generativeai.${TF_VAR_region}.oci.oraclecloud.com/20251112/hostedApplications/${mcp_application_id}/actions/invoke/mcp"
        fi
        merge_runtime_environment "$application_details" > "$TEMP_DIR/environment-variables.json"
        oci_genai hosted-application update \
            --hosted-application-id "$application_id" \
            --environment-variables "file://$TEMP_DIR/environment-variables.json" \
            --force \
            --wait-for-state SUCCEEDED \
            --max-wait-seconds 1200 \
            --wait-interval-seconds 10 >/dev/null
        application_details=$(oci_genai hosted-application get \
            --hosted-application-id "$application_id")
    fi

    jq -e '.data["freeform-tags"] // .data.freeformTags // {}' <<<"$application_details" > "$TEMP_DIR/freeform-tags.json"
    jq -n --arg uri "$CONTAINER_URI" --arg tag "$IMAGE_TAG" \
        '{artifactType: "SIMPLE_DOCKER_ARTIFACT", containerUri: $uri, tag: $tag, isVulnerabilityScanRequired: false}' \
        > "$TEMP_DIR/active-artifact.json"

    local deployments deployment_id
    deployments=$(oci_genai hosted-deployment-collection list-hosted-deployments \
        --compartment-id "$TF_VAR_compartment_ocid" \
        --application-id "$application_id" \
        --all)
    deployment_id=$(deployment_id_or_empty "$deployments")

    if [ -z "$deployment_id" ]; then
        oci_genai hosted-deployment create \
            --compartment-id "$TF_VAR_compartment_ocid" \
            --hosted-application-id "$application_id" \
            --active-artifact "file://$TEMP_DIR/active-artifact.json" \
            --freeform-tags "file://$TEMP_DIR/freeform-tags.json" \
            --wait-for-state SUCCEEDED \
            --max-wait-seconds 1200 \
            --wait-interval-seconds 10 >/dev/null
    else
        # An artifact is immutable once attached to a deployment. Add the newly
        # pushed tag first, then make that returned artifact active.
        oci_genai hosted-deployment add \
            --hosted-deployment-id "$deployment_id" \
            --artifact "file://$TEMP_DIR/active-artifact.json" \
            --wait-for-state SUCCEEDED \
            --max-wait-seconds 1200 \
            --wait-interval-seconds 10 >/dev/null
        oci_genai hosted-deployment update \
            --hosted-deployment-id "$deployment_id" \
            --active-artifact "file://$TEMP_DIR/active-artifact.json" \
            --force \
            --wait-for-state SUCCEEDED \
            --max-wait-seconds 1200 \
            --wait-interval-seconds 10 >/dev/null
    fi

    echo "Hosted Deployment synchronized for $display_name"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
