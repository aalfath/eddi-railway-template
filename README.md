[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/eddi?utm_medium=integration&utm_source=button&utm_campaign=eddi)

# EDDI on Railway

One-click [Railway](https://railway.com) template for [EDDI](https://github.com/labsai/EDDI) **6.7.1**, the open-source (Apache-2.0) AI agent management platform from LABS.AI, with MongoDB and a generated login in front.

## What it deploys

| Service | Source | What it does |
| --- | --- | --- |
| **EDDI** | this repo (`Dockerfile`): `labsai/eddi:6.7.1@sha256:3f2a38d1621d28165b119ab98881c473ffc9fbdbd4b29b835e78be1a44d820fb` + Caddy `2.11.9-alpine` | Public service. Caddy on `PORT` 8080 asks for HTTP basic auth and forwards to EDDI on `127.0.0.1:7070`. `/healthz` (EDDI's readiness, database included) is open for Railway's health check. |
| **MongoDB** | `mongo:7.0.43@sha256:1f995ad6fdb93244a1addab1b58f934a0bc2f5643c38e02f5e9d7f0c7d227a7b` | Database (agents, conversations, vault, audit trail), private network only, volume at `/data/db`. |

Upstream's Docker setup has no login unless Keycloak is added, and refuses to publish EDDI without one. Here EDDI listens on loopback only and Caddy is the only way in, so the Manager, REST API, `/mcp`, `/v1` and the secrets vault all need the generated password. Upstream's `bind-guard` and `mongodb-app-user` helper containers are left out: the login replaces the first, and EDDI connects with the generated MongoDB user.

## Variables

| Service | Variable | Default | Notes |
| --- | --- | --- | --- |
| EDDI | `EDDI_USERNAME` | `admin` | Login user name |
| EDDI | `EDDI_PASSWORD` | `${{secret(24)}}` | Login password (generated). Copy it from the Variables tab |
| EDDI | `EDDI_VAULT_MASTER_KEY` | `${{secret(48)}}` | Encrypts stored API keys. Never change it after the first start |
| EDDI | `MONGODB_CONNECTIONSTRING` | reference to MongoDB | |
| EDDI | `PORT` | `8080` | Caddy's port |
| MongoDB | `MONGO_INITDB_ROOT_USERNAME` / `MONGO_INITDB_ROOT_PASSWORD` | `eddi` / `${{secret(32)}}` | Read on first start only |

Nothing has to be filled in at deploy time. Add your LLM provider's API key in the Manager (agent wizard or Platform Operator) after the first login.

## After deploy

1. Copy `EDDI_PASSWORD` from the EDDI service's Variables tab.
2. Open `https://YOUR-DOMAIN/manage/` and sign in as `admin`.
3. Create an agent with the wizard (`/manage/agents/wizard`) or the Platform Operator (`/manage/operator`).

API and MCP clients send the same login as HTTP basic auth (`Authorization: Basic base64(admin:password)`). The MCP endpoint is `https://YOUR-DOMAIN/mcp` (streamable HTTP).

## Resources

Tested with 0.5 GB RAM / 1 vCPU per service (Railway's Free plan limit): EDDI about 270 MB idle and 315 MB with 10 parallel conversations; MongoDB about 110 MB. The start script sizes the JVM heap from the container's memory limit (45 % below 1.2 GB, 75 % above, as upstream) and its CPU count from `cpu.max`. If EDDI or Caddy stops, the container exits 1 so Railway restarts it.

## Updates

The EDDI service builds from this repo's `main` branch. When we bump the pinned EDDI version here, Railway shows everyone who deployed the template an update notice, and they choose when to apply it. Read [`CHANGELOG.md`](CHANGELOG.md) first; breaking changes are listed at the top of each entry. MongoDB's image is not changed by template updates.

`docker-compose.test.yml` runs the same two services locally (`docker compose -f docker-compose.test.yml up --build`, then http://localhost:8080 with `admin` / `localtestpassword123`). It's for testing only.
