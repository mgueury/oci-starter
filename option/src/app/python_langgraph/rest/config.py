import json
import os
import threading
from pathlib import Path
from typing import Any

import httpx
import oci
import oci_openai
from openai import OpenAI

CONFIG_FILE = Path(os.getenv("APP_CONFIG_FILE", Path(__file__).with_name("config.json")))

CONFIG_FIELDS: list[dict[str, str]] = [
    {"name": "REGION", "label": "Region", "type": "LOV"},
    {"name": "GENAI_MODEL", "label": "GenAI model", "type": "LOV"},
    {"name": "VECTOR_STORE_ID", "label": "Vector store", "type": "LOV", "optional": "true"},
    {"name": "SEMANTIC_STORE_ID", "label": "Semantic store", "type": "LOV", "optional": "true"},
    {"name": "MCP_SERVER_URL", "label": "MCP server URL", "type": "TEXT", "optional": "true"},
    {"name": "MCP_AUTH_TYPE", "label": "MCP authentication", "type": "LOV"},
    {"name": "AUTH_TYPE", "label": "OCI authentication", "type": "LOV"},
]

FIELD_NAMES = {field["name"] for field in CONFIG_FIELDS}
OCI_REGIONS: list[dict[str, str]] = [
    {"name": "Brazil East (Sao Paulo)", "id": "sa-saopaulo-1"},
    {"name": "Germany Central (Frankfurt)", "id": "eu-frankfurt-1"},
    {"name": "India South (Hyderabad)", "id": "ap-hyderabad-1"},
    {"name": "Japan Central (Osaka)", "id": "ap-osaka-1"},
    {"name": "Saudi Arabia Central (Riyadh)", "id": "me-riyadh-1"},
    {"name": "UAE Central (Abu Dhabi)", "id": "me-abudhabi-1"},
    {"name": "UAE East (Dubai)", "id": "me-dubai-1"},
    {"name": "UK South (London)", "id": "uk-london-1"},
    {"name": "US East (Ashburn)", "id": "us-ashburn-1"},
    {"name": "US Midwest (Chicago)", "id": "us-chicago-1"},
    {"name": "US West (Phoenix)", "id": "us-phoenix-1"},
]
FIXED_LOVS: dict[str, list[str]] = {
    "REGION": [region["id"] for region in OCI_REGIONS],
    "AUTH_TYPE": ["INSTANCE_PRINCIPAL", "RESOURCE_PRINCIPAL"],
    "MCP_AUTH_TYPE": ["NONE", "BEARER"],
}

COMPARTMENT_OCID = os.getenv("TF_VAR_compartment_ocid")
PROJECT_OCID = os.getenv("TF_VAR_project_ocid") or os.getenv("PROJECT_OCID")

_CONFIG_LOCK = threading.Lock()
_CONFIG_WARNING: str | None = None


class ConfigError(ValueError):
    pass


def env_config() -> dict[str, str]:
    return {
        "REGION": os.getenv("REGION") or os.getenv("TF_VAR_region") or "eu-frankfurt-1",
        "GENAI_MODEL": os.getenv("GENAI_MODEL") or "openai.gpt-oss-120b",
        "VECTOR_STORE_ID": os.getenv("VECTOR_STORE_ID") or "",
        "SEMANTIC_STORE_ID": os.getenv("SEMANTIC_STORE_ID") or "",
        "MCP_SERVER_URL": os.getenv("MCP_SERVER_URL") or "",
        "MCP_AUTH_TYPE": os.getenv("MCP_AUTH_TYPE") or "NONE",
        "AUTH_TYPE": os.getenv("AUTH_TYPE") or "INSTANCE_PRINCIPAL",
    }


def _read_raw_config() -> dict[str, str]:
    if not CONFIG_FILE.exists():
        return {}

    try:
        with CONFIG_FILE.open("r", encoding="utf-8") as config_file:
            data = json.load(config_file)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{CONFIG_FILE.name} is not valid JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise ConfigError(f"{CONFIG_FILE.name} must contain a JSON object")

    return {
        key: "" if value is None else str(value)
        for key, value in data.items()
        if key in FIELD_NAMES
    }


def _complete_config(values: dict[str, str]) -> dict[str, str]:
    return {field["name"]: values.get(field["name"], "") for field in CONFIG_FIELDS}


def initial_config() -> dict[str, str]:
    if CONFIG_FILE.exists():
        return _complete_config(_read_raw_config())
    return _complete_config(env_config())


def _write_raw_config(values: dict[str, str]) -> None:
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    payload = {field["name"]: values.get(field["name"], "") for field in CONFIG_FIELDS}
    with CONFIG_FILE.open("w", encoding="utf-8") as config_file:
        json.dump(payload, config_file, indent=2)
        config_file.write("\n")


def get_effective_config() -> dict[str, str]:
    with _CONFIG_LOCK:
        return dict(CONFIG)


def save_config(updates: dict[str, Any]) -> dict[str, str]:
    global CONFIG, _CONFIG_WARNING

    if not isinstance(updates, dict):
        raise ConfigError("Configuration payload must be a JSON object")

    unknown_fields = sorted(set(updates) - FIELD_NAMES)
    if unknown_fields:
        raise ConfigError(f"Unknown configuration field(s): {', '.join(unknown_fields)}")

    with _CONFIG_LOCK:
        next_values = dict(CONFIG)

        for name, value in updates.items():
            next_values[name] = "" if value is None else str(value).strip()

        CONFIG = dict(next_values)
        try:
            _write_raw_config(next_values)
            _CONFIG_WARNING = None
        except OSError as exc:
            _CONFIG_WARNING = (
                f"Warning: could not write {CONFIG_FILE}. "
                "Configuration is saved only in memory."
            )
            print(f"{_CONFIG_WARNING} {exc}", flush=True)

    return get_effective_config()


def get_config_warning() -> str | None:
    return _CONFIG_WARNING


CONFIG: dict[str, str] = initial_config()


def get_lov(field_name: str, values: dict[str, Any] | None = None) -> list[str]:
    if field_name in FIXED_LOVS:
        return FIXED_LOVS[field_name]
    values_list, _labels = get_dynamic_lov(field_name, values)
    return values_list


def get_lov_labels(field_name: str, values: dict[str, Any] | None = None) -> dict[str, str]:
    if field_name == "REGION":
        return region_labels()
    _values_list, labels = get_dynamic_lov(field_name, values)
    return labels


def get_dynamic_lov(
    field_name: str,
    values: dict[str, Any] | None = None,
) -> tuple[list[str], dict[str, str]]:
    if field_name == "VECTOR_STORE_ID":
        update_config_for_lov(values)
        return get_vector_stores()
    if field_name == "SEMANTIC_STORE_ID":
        update_config_for_lov(values)
        return get_semantic_stores()
    if field_name == "GENAI_MODEL":
        update_config_for_lov(values)
        return get_genai_models()
    return [], {}


def update_config_for_lov(values: dict[str, Any] | None) -> None:
    if not values:
        return

    with _CONFIG_LOCK:
        for key in ("REGION", "AUTH_TYPE"):
            if values.get(key):
                CONFIG[key] = str(values[key]).strip()


def list_configuration_parameters() -> dict[str, Any]:
    values = get_effective_config()
    parameters = []

    for field in CONFIG_FIELDS:
        name = field["name"]
        parameters.append(
            {
                **field,
                "value": values.get(name, ""),
                "lov": get_lov(name, values) if field["type"] == "LOV" else [],
                "lov_labels": get_lov_labels(name, values) if field["type"] == "LOV" else {},
            }
        )

    response: dict[str, Any] = {"parameters": parameters, "values": values}
    if _CONFIG_WARNING:
        response["warning"] = _CONFIG_WARNING
    return response


def _build_oci_signer(auth_type: str) -> Any:
    if auth_type == "RESOURCE_PRINCIPAL":
        return oci.auth.signers.get_resource_principals_signer()
    return oci.auth.signers.InstancePrincipalsSecurityTokenSigner()


def oci_genai_client() -> Any:
    region = CONFIG.get("REGION")
    if not region:
        raise ConfigError("REGION is not configured")

    return oci.generative_ai.GenerativeAiClient(
        config={},
        signer=_build_oci_signer(CONFIG.get("AUTH_TYPE", "")),
        service_endpoint=f"https://generativeai.{region}.oci.oraclecloud.com",
    )


def _build_openai_auth() -> Any:
    if CONFIG.get("AUTH_TYPE") == "RESOURCE_PRINCIPAL":
        return oci_openai.OciResourcePrincipalAuth()
    return oci_openai.OciInstancePrincipalAuth()


def oci_openai_client() -> OpenAI:
    region = CONFIG.get("REGION")
    if not region:
        raise ConfigError("REGION is not configured")
    if not PROJECT_OCID:
        raise ConfigError("PROJECT_OCID is not configured")    

    return OpenAI(
        base_url=f"https://inference.generativeai.{region}.oci.oraclecloud.com/20231130/openai/v1",
        api_key="unused",
        http_client=httpx.Client(
            auth=_build_openai_auth(),
            headers={
                "opc-compartment-id": COMPARTMENT_OCID,
            },
        ),
        project=PROJECT_OCID,
    )


def _model_identifier(model: Any) -> str:
    for attribute in ("id", "model_id", "display_name"):
        value = getattr(model, attribute, None)
        if value:
            return str(value)
    if isinstance(model, dict):
        for attribute in ("id", "model_id", "display_name"):
            value = model.get(attribute)
            if value:
                return str(value)
    return ""


def _display_name(resource: Any, fallback: str) -> str:
    if isinstance(resource, dict):
        return str(
            resource.get("display_name")
            or resource.get("displayName")
            or resource.get("name")
            or fallback
        )
    return str(
        getattr(resource, "display_name", None)
        or getattr(resource, "name", None)
        or fallback
    )


def _resource_identifier(resource: Any, *attributes: str) -> str:
    if isinstance(resource, dict):
        for attribute in attributes:
            value = resource.get(attribute) or resource.get(_snake_to_camel(attribute))
            if value:
                return str(value)
        return ""

    for attribute in attributes:
        value = getattr(resource, attribute, None)
        if value:
            return str(value)
    return ""


def _snake_to_camel(value: str) -> str:
    head, *tail = value.split("_")
    return head + "".join(part.title() for part in tail)


def region_labels() -> dict[str, str]:
    return {
        region["id"]: f"{region['name']} - {region['id']}"
        for region in OCI_REGIONS
    }


def _openai_page_items(response: Any) -> list[Any]:
    if hasattr(response, "auto_paging_iter"):
        return list(response.auto_paging_iter())
    items = getattr(response, "data", response)
    return list(items or [])


def get_vector_stores() -> tuple[list[str], dict[str, str]]:
    try:
        client = oci_openai_client()
        response = client.vector_stores.list()
        print(f"Debug: {response}", flush=True)
        items = _openai_page_items(response)
        labels = {
            store_id: _display_name(store, store_id)
            for store in items
            if (store_id := _resource_identifier(store, "id", "vector_store_id"))
        }
        stores = sorted(labels, key=lambda store_id: labels[store_id].lower())
    except Exception as exc:
        if isinstance(exc, ConfigError):
            raise
        print(f"Unable to load OCI vector stores for region {CONFIG.get('REGION')}: {exc}", flush=True)
        stores = []
        labels = {}

    return stores, labels


def get_semantic_stores() -> tuple[list[str], dict[str, str]]:
    try:
        client = oci_genai_client()

        # sort_by="displayName" cause HTTP-400
        response = oci.pagination.list_call_get_all_results(
            client.list_semantic_stores,
            compartment_id=COMPARTMENT_OCID,
            sort_by="displayName",
            sort_order="ASC",
        )
        items = getattr(response.data, "items", response.data)
        labels = {
            store_id: _display_name(store, store_id)
            for store in items
            if (store_id := _resource_identifier(store, "id"))
        }
        stores = sorted(labels, key=lambda store_id: labels[store_id].lower())
    except Exception as exc:
        if isinstance(exc, ConfigError):
            raise
        print(f"Unable to load OCI semantic stores for region {CONFIG.get('REGION')}: {exc}", flush=True)
        stores = []
        labels = {}

    return stores, labels


def get_genai_models() -> tuple[list[str], dict[str, str]]:
    try:
        client = oci_genai_client()

        response = oci.pagination.list_call_get_all_results(
            client.list_models,
            compartment_id=COMPARTMENT_OCID,
        )
        items = getattr(response.data, "items", response.data)
        labels = {
            model_id: _display_name(model, model_id)
            for model in items
            if (model_id := _model_identifier(model))
        }
        models = sorted(labels, key=lambda model_id: labels[model_id].lower())
    except Exception as exc:
        if isinstance(exc, ConfigError):
            raise
        print(f"Unable to load OCI GenAI models for region {CONFIG.get('REGION')}: {exc}", flush=True)
        models = []
        labels = {}

    return models, labels
