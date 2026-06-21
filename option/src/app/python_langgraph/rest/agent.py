from langchain_openai import ChatOpenAI
from langchain_oci import ChatOCIGenAI
from langgraph.prebuilt import create_react_agent
from langgraph.graph import StateGraph
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_mcp_adapters.interceptors import MCPToolCallRequest
import asyncio
import os
import pprint
import httpx
import oci_openai 
from typing import Any
from config import get_effective_config

def get_env( name ):
    value = os.getenv( name )
    print( f"Env {name}={value}")
    return value

COMPARTMENT_OCID = ""
PROJECT_OCID = ""
VECTOR_STORE_ID = ""
SEMANTIC_STORE_ID = ""
REGION = ""
GENAI_MODEL = ""
MCP_SERVER_URL = ""
MCP_AUTH_TYPE = ""
AUTH_TYPE = ""

# auth = oci_openai.OciInstancePrincipalAuth()
# llm = ChatOpenAI(
#     model="xai.grok-4-fast-reasoning",
#     api_key="OCI",
#     base_url="https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1",
#     http_client=httpx.Client(
#         auth=auth,
#         headers={"CompartmentId": COMPARTMENT_OCID}
#     ),
# )

def normalize_region(region: str) -> str:
    if region == "eu-amsterdam-1":
        return "eu-frankfurt-1"
    return region


def apply_runtime_config(config: dict[str, str] | None = None) -> None:
    global COMPARTMENT_OCID, PROJECT_OCID, VECTOR_STORE_ID, SEMANTIC_STORE_ID
    global REGION, GENAI_MODEL, MCP_SERVER_URL, MCP_AUTH_TYPE, AUTH_TYPE

    app_config = config or get_effective_config()
    PROJECT_OCID = os.getenv("PROJECT_OCID") or ""
    COMPARTMENT_OCID = os.getenv("TF_VAR_compartment_ocid")
    VECTOR_STORE_ID = app_config["VECTOR_STORE_ID"]
    SEMANTIC_STORE_ID = app_config["SEMANTIC_STORE_ID"]
    REGION = normalize_region(app_config["REGION"])
    GENAI_MODEL = app_config["GENAI_MODEL"]
    MCP_SERVER_URL = app_config["MCP_SERVER_URL"]
    MCP_AUTH_TYPE = app_config["MCP_AUTH_TYPE"]
    AUTH_TYPE = app_config["AUTH_TYPE"]

    print(f"Config REGION={REGION}")
    print(f"Config GENAI_MODEL={GENAI_MODEL}")
    print(f"Config PROJECT_OCID={PROJECT_OCID}")
    print(f"Config COMPARTMENT_OCID={COMPARTMENT_OCID}")
    print(f"Config VECTOR_STORE_ID={VECTOR_STORE_ID}")
    print(f"Config SEMANTIC_STORE_ID={SEMANTIC_STORE_ID}")
    print(f"Config MCP_SERVER_URL={MCP_SERVER_URL}")
    print(f"Config MCP_AUTH_TYPE={MCP_AUTH_TYPE}")
    print(f"Config AUTH_TYPE={AUTH_TYPE}")


def build_llm() -> ChatOCIGenAI:
    return ChatOCIGenAI(
        auth_type="API_KEY" if "LIVELABS" in os.environ else AUTH_TYPE,
        model_id=GENAI_MODEL,
        # model_id="meta.llama-4-scout-17b-16e-instruct",
        # model_id="cohere.command-a-03-2025",
        service_endpoint="https://inference.generativeai."+REGION+".oci.oraclecloud.com",
        # model_id="xai.grok-4.3",
        # service_endpoint="https://inference.generativeai.us-chicago-1.oci.oraclecloud.com",
        compartment_id=COMPARTMENT_OCID,
        is_stream=False,
        model_kwargs={"temperature": 0}
    )

def remove_empty_parameter_names(args: dict[str, Any] | None) -> dict[str, Any]:
    """Remove tool arguments whose parameter name is empty or only whitespace."""
    if not args:
        return {}

    return {
        key: value
        for key, value in args.items()
        if isinstance(key, str) and key.strip()
    }

# See https://docs.langchain.com/oss/python/langchain/mcp#accessing-runtime-context
async def inject_user_context(
    request: MCPToolCallRequest,
    handler,
):
    """Inject user credentials into MCP tool calls and keep agent runs alive on tool errors."""
    print( "--- request ----" )
    pprint.pprint( request )
    runtime = request.runtime
    user_id = runtime.config["configurable"]["user_id"]
    auth_user = runtime.config["configurable"]["langgraph_auth_user"]
    auth_header = auth_user.dict().get("auth_header")
    print( f"<inject_user_context> user_id={user_id}", flush=True )
    # print( f"<inject_user_context> auth_header={auth_header}", flush=True )
    # modified_request = request.override( headers = { "Authorization": f"User {user_id}" } )
    cleaned_args = remove_empty_parameter_names(request.args)
    # Forward the original request credentials to every MCP tool call.
    headers = {"Authorization": auth_header} if MCP_AUTH_TYPE == "BEARER" and auth_header else {}
    modified_request = request.override(args=cleaned_args, headers=headers)
    try:
        return await handler(modified_request)
    except Exception as first_error:
        message = str(first_error)
        print(f"<inject_user_context> tool call failed: {message}", flush=True)

        # Retry once only for likely transient errors.
        transient_markers = ["timeout", "temporar", "connection reset", "503", "502", "429"]
        if any(marker in message.lower() for marker in transient_markers):
            print("<inject_user_context> retrying transient tool error once", flush=True)
            await asyncio.sleep(0.5)
            try:
                return await handler(modified_request)
            except Exception as second_error:
                message = str(second_error)
                print(f"<inject_user_context> retry failed: {message}", flush=True)

        # For validation/format errors, return structured payload instead of raising,
        # so the agent can reason on the error and try a corrected tool call.
        return {
            "status": "tool_error",
            "retryable_by_agent": True,
            "error": message,
            "guidance": "Tool call failed. Adjust parameters based on this error and retry with corrected values.",
        }

async def init( agent_name, prompt, tools_list, callback_handler=None ) -> StateGraph:

    # Build the graph once at process startup; app.py streams runs from this object.
    # Waiting is important, since after reboot the MCP server could start afterwards.
    delay = 10
    client = None
    tools_filtered = []
    llm = build_llm()
    if not MCP_SERVER_URL:
        print("MCP_SERVER_URL is not configured; starting agent without MCP tools")
        return create_react_agent(
            model=llm,
            tools=[],
            prompt=prompt,
            name=agent_name
        )

    for attempt in range(1, 10):
        try:
            print(f"Connecting to MCP {attempt}...")
            client = MultiServerMCPClient(
                {
                    "McpServer": {
                        "transport": "streamable_http",
                        "url": MCP_SERVER_URL,                     
                    },
                },
                tool_interceptors=[inject_user_context],
            )
            tools = await client.get_tools()
            print( "-- tools ------------------------------------------------------------")
            pprint.pprint( tools )
            # Filter tools.
            tools_filtered = []
            for tool in tools:
                if tools_list==None or tool.name in tools_list:
                    tools_filtered.append( tool )
            print( "-- tools_filtered ---------------------------------------------------")
            pprint.pprint( tools_filtered )
            break
        except Exception as e:
            print(f"Connection failed {attempt}: {e}")            
            print(f"Waiting for {delay} seconds before the next attempt...")
            await asyncio.sleep(delay)

    if client==None:
        raise RuntimeError("ERROR: connection to MCP Failed")

    agent = create_react_agent(
        model=llm,
        tools=tools_filtered,
        prompt=prompt,
        name=agent_name
    ) 
    return agent    
prompt = """You are an agent that use the tools you got access to.

INSTRUCTIONS:
- Assist ONLY with research-related tasks, DO NOT do any math.
- When using a MCP tool, take care not to  pass empty parameters name like "", or {"":{}}
- To draw a diagram, use mermaid   
- If not, use MarkDown to give a clear and short answer to the user.
- Do not call the same tools twice with the same parameters
"""

async def build_agent() -> StateGraph:
    apply_runtime_config(get_effective_config())
    return await init("agent", prompt, None)


class AgentRuntime:
    def __init__(self, graph: StateGraph):
        self._graph = graph
        self._reload_lock = asyncio.Lock()

    async def astream(self, *args, **kwargs):
        graph = self._graph
        async for state in graph.astream(*args, **kwargs):
            yield state

    async def reload(self) -> None:
        async with self._reload_lock:
            self._graph = await build_agent()


agent = AgentRuntime(asyncio.run(build_agent()))


async def reload_agent_config() -> None:
    await agent.reload()
