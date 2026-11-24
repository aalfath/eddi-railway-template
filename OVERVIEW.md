# Deploy and Host EDDI on Railway

EDDI is an open-source (Apache-2.0) platform from LABS.AI for running and governing AI agents. You build agents in its web Manager, connect them to LLM providers, MCP servers and APIs, set budgets, approvals and guardrails, and talk to them through its REST API, an OpenAI-compatible `/v1` API or its own MCP server.

## About Hosting EDDI

EDDI is a Java (Quarkus) server that keeps everything (agents, conversations, the encrypted secrets vault, audit trail) in MongoDB. Upstream's Docker setup has no login unless you add Keycloak, so this template puts a small Caddy front in the EDDI service that asks for a generated username and password before anything reaches the Manager, the API, `/mcp` or the vault. EDDI itself listens only inside its container. MongoDB runs on a private-network-only service with its own volume and a generated password, and the vault master key is generated too. There is nothing to fill in at deploy time: you add your LLM provider's key in the Manager after the first login.

## Common Use Cases

* Build and run LLM agents (OpenAI, Anthropic, Gemini, Mistral, OpenRouter, Groq, any OpenAI-compatible server) with tools, RAG and memory, behind one API
* Put cost budgets, human approval steps and tool guardrails around agents your team or customers use
* Serve agents to Open WebUI or other OpenAI-protocol clients via `/v1`, or to coding assistants via EDDI's MCP server

## Dependencies for EDDI Hosting

* EDDI (`labsai/eddi`, pinned by version and digest) with a Caddy login front, built from [aalfath/eddi-railway-template](https://github.com/aalfath/eddi-railway-template)
* MongoDB 7.0 (official `mongo` image, pinned) on a Railway volume

### Deployment Dependencies

* EDDI on GitHub: https://github.com/labsai/EDDI (release notes: https://github.com/labsai/EDDI/releases)
* EDDI Docker documentation: https://github.com/labsai/EDDI/blob/main/docs/docker.md
* An API key from the LLM provider you want to use (for example https://platform.openai.com/api-keys), entered in the Manager after deploy

### Implementation Details

**Services**

* **EDDI**: the public service. Caddy answers on `PORT` 8080, checks the login and forwards to EDDI on `127.0.0.1:7070`. The health check is `/healthz` (EDDI's readiness, including the database), open without a login.
* **MongoDB**: the database, reachable only on Railway's private network, with its data on a volume at `/data/db`.

**After deploy**

1. Open the EDDI service's Variables tab and copy `EDDI_PASSWORD` (the user name is `EDDI_USERNAME`, `admin` by default).
2. Open `https://YOUR-DOMAIN/manage/` and sign in.
3. Create your first agent with the agent wizard (`/manage/agents/wizard`) or activate the Platform Operator (`/manage/operator`): pick a provider, paste its API key and a model. EDDI stores the key encrypted in its vault (`EDDI_VAULT_MASTER_KEY`). Keep that variable unchanged, or the stored keys can't be decrypted.

API clients use the same login as HTTP basic auth, for example `curl -u admin:YOUR-PASSWORD https://YOUR-DOMAIN/agentstore/agents/descriptors`. An MCP client config for EDDI's MCP server (streamable HTTP):

```json
{
  "mcpServers": {
    "eddi": {
      "url": "https://YOUR-DOMAIN/mcp",
      "headers": { "Authorization": "Basic BASE64-OF-admin:YOUR-PASSWORD" }
    }
  }
}
```

**Good to know**

* Everyone who signs in shares the one admin login. For per-user accounts and roles, upstream uses Keycloak (OIDC), which isn't part of this template.
* Sizing: on Railway's 0.5 GB per service, EDDI used about 270 MB idle and 315 MB with 10 conversations running at once, and MongoDB about 110 MB. Railway restarts EDDI if it crashes.
* Optional features (SMTP mail, Slack, Keycloak, NATS, monitoring) are set with EDDI's own environment variables, listed in its configuration reference.
* Updates: the EDDI service builds from the template's GitHub repo, which pins an exact EDDI release. When we move to a new EDDI version, Railway shows an update notice in your project, and you choose when to apply it. Read the repo's `CHANGELOG.md` first.

## Why Deploy EDDI on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying EDDI on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
