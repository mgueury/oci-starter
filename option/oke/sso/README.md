# OCI SSO for the shared OKE Gateway

This optional deployment protects every route served by `gateway/oke-gateway` with OCI IAM Identity Domains authentication. It is disabled unless `oci_sso_enabled=true`.

## Identity Domain application

Terraform creates the confidential application, enables the Authorization Code grant,
and configures `https://www.oracloud.be/oauth2/callback` as its callback URL.
The deployment permits all users that successfully authenticate.

The Gateway, certificate, and oauth2-proxy runtime configuration use `dns_name`.
Because `dns_name` is currently supplied only through the generated shell
`tf_vars.sh`, changing it does not change the Terraform-managed Identity Domain
application. Before using a different hostname, update the application callback,
logout, and post-logout redirect URLs in OCI Identity Domains to that hostname.

## Secret configuration

Set the following non-secret values in `terraform.tfvars`:

```bash
idcs_url = "https://idcs-930d7b2ea2cb46049963ecba3049f509.identity.oraclecloud.com:443"
oci_sso_enabled = true
dns_name = "www.example.com"
certificate_email = "platform@example.com"
```

Terraform generates the OIDC client secret and the 32-byte oauth2-proxy cookie
secret. Do not set either manually.

OCI Identity Domains publishes its discovery document at the tenant URL but
advertises the shared `https://identity.oraclecloud.com/` issuer. The deployment
therefore retains the tenant discovery URL and disables only oauth2-proxy's
issuer-string comparison; token signature, audience, client, and TLS validation
remain enabled.

OCI can set `email_verified=false` in an otherwise valid ID token. Because this
installation intentionally permits **all authenticated users**, oauth2-proxy also
accepts that claim. Token signature, expiry, audience, and client validation remain
enforced.

## Behaviour

- Browser requests without an SSO session redirect to OCI Identity Domains and return to their original URL after login.
- OCI tokens can require split session cookies (`__Host-oracloud-sso_0`, `_1`, ...); the gateway recognises these as one authenticated session.
- After oauth2-proxy authorizes a request, Istio forwards its original path to the selected application backend.
- OAuth2-proxy returns `200` for an approved authorization check, as required by the Envoy external-authorization protocol.
- API requests receive an authentication denial rather than an HTML redirect.
- `/oauth2/*`, `/healthz`, and `/ready` remain reachable to complete sign-in and health checks.
- The validated identity is forwarded to applications through `X-Auth-Request-User`, `X-Auth-Request-Email`, and `X-Auth-Request-Access-Token` headers. Applications must treat these headers as trusted only when they arrive through the Gateway.

Run the normal OKE configuration/deployment workflow after setting the profile variables. The SSO resources are reconciled on subsequent runs.

## Durable Istio add-on configuration

The OCI-managed Istio add-on owns the `istio-system/istio` ConfigMap. The SSO
integration adds the `oauth2-proxy` external-authorization provider to that
ConfigMap, so a default add-on upgrade can otherwise remove it and break all
protected routes.

The project configures the add-on with `customizeConfigMap=true`, the OCI
supported setting that preserves ConfigMap customizations during managed add-on
updates. Each normal OKE configuration run checks the effective Istio add-on
configuration and updates it when that setting or the Gateway API mode differs.
It then waits for the add-on and `istiod` before applying the SSO resources.

When this setting is enabled, an OCI-managed add-on can start without creating
the legacy `istio-system/istio` ConfigMap. The SSO workflow creates a minimal
MeshConfig only when that ConfigMap is absent, then merges the oauth2-proxy
provider into it. It never overwrites an existing operator-managed MeshConfig.

To verify a deployed cluster, confirm that the Istio add-on reports
`customizeConfigMap=true`, then confirm that `istio-system/istio` contains an
extension provider named `oauth2-proxy`. An unauthenticated browser request to
the application must redirect to OCI Identity Domains; an authenticated request
must reach its route. Re-run the normal OKE configuration after an add-on update
to repair a deleted provider. The workflow stops before applying the SSO policy
if the provider is not present after reconciliation.

If OCI still removes the provider after `customizeConfigMap=true` is confirmed,
do not disable the add-on in place. First migrate to a compatible self-managed
Istio control plane, recreate the Gateway API gateway and OAuth2 Proxy external
authorization policy, validate SSO through its new load-balancer address, and
cut over DNS. Only then remove the OCI Istio add-on and its obsolete resources.
