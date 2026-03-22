# Program-Specific Rules (OCI Vibe + LangGraph + MCP)

These rules define behavior specific to this repository implementation under `starter/src`.

## Database rules

- Oracle schema initialization is defined in `src/db/oracle.sql` and executed by `src/db/db_init.sh`.
- `oracle.sql` currently defines and seeds:
  - `DEPT(DEPTNO, DNAME, LOC)`
- Any change to table structure or seed data must be made in `oracle.sql` to remain deployable.

## MCP server rules

- MCP server entrypoint is `src/app/src_mcp_server/mcp_server.py`.
- Server transport is HTTP on port `2025`.
- MCP tools are Python functions decorated with `@mcp.tool()`.
- The server includes a department data tool `get_dept_data` that reads from Oracle `DEPT` using `DB_USER`, `DB_PASSWORD`, and `DB_URL`.

## LangGraph agent rules

- Agent runtime is in `src/app/src_langgraph/agent/agent.py`.
- It connects to the MCP server via `MCP_SERVER_URL` using `MultiServerMCPClient`.
- Tool calls are mediated by interceptor `inject_user_context` to pass authorization context.
- Model provider uses OCI Generative AI configuration via environment variables.

## UI/chat rules

- Chat UI entry files are `src/ui/ui/chat.html` and `src/ui/ui/chat.js`.
- The frontend sends streaming run requests to `/langgraph/server/threads/{thread_id}/runs/stream`.
- On OpenID paths, user info and CSRF token are obtained from `/openid/userinfo`.

## Routing and deployment rules

- Compute NGINX routing is declared in `src/compute/nginx_app.locations`.
- `/langgraph/server/` is proxied to local port `2024`.
- Kubernetes manifests are maintained per service in `src/app/k8s_langgraph.yaml`, `src/app/k8s_mcp_server.yaml`, and `src/ui/ui.yaml`.