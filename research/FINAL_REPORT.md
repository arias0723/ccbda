# Barcelona Smart City — Final Project Report

**UPC CCBDA · Team 11 · May 2026**

| Member | Role |
|--------|------|
| Jakub Dusza | Mobility (Bicing + Transit) + MCP server + Infrastructure |
| Mark Welf Atzberger | Air Quality + AWS architecture design + MCP research |
| Jia Lyu | Weather + Research coordination |
| Jose Ricardo Arias Perez | UV + Pollen + Bedrock research |

---

## 1. What Does the Project Do?

Barcelona Smart City is a **live city data platform** that turns any compatible AI assistant into a Barcelona-aware agent capable of answering real-time questions about mobility, environmental conditions, and public health indicators.

The system ingests six live data streams — Bicing bike-share, public transit, air quality, weather, UV radiation, and pollen — stores them in AWS DynamoDB, and exposes them through an **MCP (Model Context Protocol) server** deployed on AWS Lambda. On top of this data layer, we built two AI-powered applications:

1. **Web Chat Application** — A publicly accessible chatbot (hosted via CloudFront + S3 + API Gateway + Lambda) where an agentic loop powered by AWS Bedrock (Claude Haiku) answers natural-language questions about Barcelona using live city data. The agent autonomously decides which data tools to call, executes them, and synthesises actionable answers. Tool call traces are shown in expandable UI blocks for transparency.

2. **MCP Server Integration** — The MCP endpoint can be connected directly from claude.ai, Claude Desktop, or any MCP-compatible client, turning any AI into a city-aware assistant without bespoke integration work.

**Key capabilities demonstrated:**

- "Are there Bicing bikes near Sagrada Família right now?" → live station availability with e-bike split
- "How do I get from UPC Campus Nord to Barceloneta?" → real-time transit routing with legs, lines, and duration
- "Is today a good day to be outside?" → composite query triggering weather + UV + air quality + pollen tools in a single agent turn
- "What's the UV index and how long can I stay in the sun?" → live UVI with Diffey burn-time formula and SPF recommendation
- Historical trend queries for all data types (48h of Bicing snapshots, hourly pollution readings, UV/pollen curves)

**Live endpoints:**

- Web app: `https://dhioxm566jvi3.cloudfront.net`
- MCP server: `https://4um7sjanuc.execute-api.eu-west-1.amazonaws.com/mcp`
- AgentCore Gateway: `https://barcelona-smart-city-xwyxovrhex.gateway.bedrock-agentcore.eu-west-1.amazonaws.com/mcp`

---

## 2. Scope Differences from the Initial Draft

### Features Added (not in original plan)

| Feature | Description |
|---------|-------------|
| **UV Index vertical** | Live UV data with burn-time formula, SPF recommendations, and WHO risk categories (replaced dead noise vertical) |
| **Pollen vertical** | 5-species pollen forecasts (grass, birch, olive, mugwort, ragweed) with level classifications |
| **AWS Bedrock agentic loop** | Full agent orchestration with multi-tool calling per turn — not just single API calls |
| **CloudFront-hosted public web app** | Static site on S3 + CloudFront CDN; originally planned as local-only demo |
| **AgentCore Gateway integration** | Managed MCP proxy that auto-discovers tools, ready for Bedrock Agents SDK |
| **Expandable tool-call UI** | Transparency layer showing exactly which tools the agent called and their results |
| **Composite query handling** | Agent correctly orchestrates 4+ tools in a single turn for planning queries |
| **PRESENTATION: prompt engineering** | Tool descriptions embed rendering instructions so Claude produces rich visual output |

### Features Not Implemented (from original plan)

| Feature | Reason |
|---------|--------|
| **Noise data vertical** | Sentilo noise sensor API is dead — returns HTTP 200 with `"found": false` for all queries; no live data available |
| **Telegram bot** | Deprioritised due to time constraints; Bedrock web app was the primary deliverable |
| **AI-controlled interactive map** | The demo app has a Leaflet map with route planning, but the production Bedrock app is chat-only (no map manipulation via AI) |
| **Alert subscription system** | Not implemented; would require persistent user state and periodic checking |
| **Bedrock Guardrails** | Not configured; app relies on Claude's built-in safety |
| **RAG Knowledge Base** | Static Barcelona neighbourhood info not indexed; all answers come from live tools |
| **Conversation memory across sessions** | Each chat session is stateless; no persistence between page reloads |

---

## 3. Architecture and Code Description

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DATA SOURCES                                     │
│  Bicing GBFS · TMB GTFS · Open Data BCN · Open-Meteo · currentuvindex.com   │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │ HTTP (no API keys needed)
                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INGESTION LAYER (AWS)                                 │
│                                                                               │
│  EventBridge Schedules ──► Lambda × 5                                        │
│    • bicing_ingest         (every 5 min)  ──► BicingStations                 │
│    • air_quality_ingest    (every 1 hr)   ──► AirQualityReadings             │
│    • weather_ingest        (every 1 hr)   ──► WeatherData                    │
│    • uv_ingest             (every 1 hr)   ──► UVData                         │
│    • pollen_ingest         (every 1 hr)   ──► PollenData                     │
│                                                                               │
│  One-time Script: load_gtfs.py            ──► TransitStops (3,453 stops)     │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STORAGE LAYER                                         │
│                                                                               │
│  DynamoDB (eu-west-1, on-demand capacity, 30-day TTL)                        │
│    • BicingStations        • TransitStops       • ScheduleCache              │
│    • AirQualityReadings    • WeatherData        • UVData        • PollenData │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SERVING LAYER (MCP Server)                            │
│                                                                               │
│  API Gateway (HTTP API) ──► Lambda: mcp_server (Python, FastMCP)             │
│    • 11 tools exposed via JSON-RPC 2.0                                       │
│    • Reads from DynamoDB + calls live APIs (Transitous, UV, Pollen)           │
│    • Stateless — each request is independent Lambda invocation                │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
┌──────────────────────┐   ┌──────────────────────────────────────────────────┐
│  EXTERNAL MCP        │   │  BEDROCK CHAT APPLICATION                         │
│  CLIENTS             │   │                                                    │
│                      │   │  CloudFront ──► S3 (static HTML/JS)               │
│  • claude.ai         │   │  API Gateway ──► Lambda: smart-city-chat          │
│  • Claude Desktop    │   │    │                                               │
│  • VS Code           │   │    ├── bedrock-runtime.invoke_model (Claude Haiku) │
│                      │   │    │     agentic loop (up to 8 rounds)             │
│                      │   │    └── HTTP POST ──► MCP server (tool calls)       │
└──────────────────────┘   └──────────────────────────────────────────────────┘
```

### 3.2 Component Descriptions

#### Data Ingestion Lambdas (`aws/lambdas/`)

Five Python Lambda functions, each triggered by EventBridge on a schedule. They fetch data from public APIs and write to DynamoDB with TTL fields for automatic expiry. No external dependencies beyond `boto3` (pre-installed in Lambda runtime) and `urllib` from the standard library.

#### MCP Server (`mcp_server.py`)

The core of the platform. Built with the FastMCP Python library, deployed as a single Lambda behind API Gateway. Exposes 11 tools via the Model Context Protocol (JSON-RPC 2.0 over HTTPS). Each tool reads from DynamoDB or calls a live external API. The server is fully stateless — no sessions, no WebSockets.

#### Chat Lambda (`aws/lambdas/chat/lambda_function.py`)

Implements the agentic loop:
1. Receives user message + conversation history from the frontend
2. Fetches available tools from the MCP server (`tools/list`, cached in Lambda memory)
3. Calls Claude via `bedrock-runtime.invoke_model` with tools
4. If Claude returns `tool_use` blocks: calls MCP server for each, appends results, loops
5. When Claude returns `end_turn`: returns final text + tool call log to frontend

Runs up to 8 reasoning rounds per request (60-second Lambda timeout).

#### Web Frontend (`webapp/index.html`)

A single static HTML file with no build step, no dependencies, no framework. Uses Fetch API to POST to the chat endpoint. Renders tool call traces as collapsible blocks. DOM is built exclusively with `createElement`/`appendChild` (never `innerHTML +=`) to preserve event listeners.

#### Demo App (`demo/app.py`)

A FastAPI application for local development that includes a Leaflet map, route planner (via Transitous API), and AI chat (via Bedrock). Used during development and for the progress presentation.

#### Infrastructure Scripts (`aws/`)

- `setup.sh` — Creates all DynamoDB tables, IAM roles, S3 bucket (idempotent)
- `deploy.sh` — Packages and deploys all Lambdas + EventBridge schedules
- `pause.sh` — Disables EventBridge schedules (cost saving)
- `teardown.sh` — Deletes all AWS resources

---

## 4. Twelve-Factor Methodology Discussion

The twelve-factor methodology was evaluated and applied where appropriate for this serverless architecture:

| Factor | Application in Our Project | Compliance |
|--------|---------------------------|------------|
| **I. Codebase** | Single Git repository (`github.com/kubadusza/barcelona-smart-city`) tracked in version control. All team members work from the same repo. | ✅ Full |
| **II. Dependencies** | `requirements.txt` explicitly declares all dependencies. Lambda functions rely only on `boto3` (pre-installed in runtime) + standard library — no implicit system dependencies. | ✅ Full |
| **III. Config** | Environment variables for all configuration: `AWS_REGION`, `BEDROCK_REGION`, `DYNAMO_REGION`, `BEDROCK_MODEL_ID`, `PORT`. No hardcoded credentials. | ✅ Full |
| **IV. Backing services** | DynamoDB, Bedrock, and external APIs are treated as attached resources, configured via environment variables and IAM roles. Switching regions or accounts requires only changing env vars. | ✅ Full |
| **V. Build, release, run** | Deployment scripts (`deploy.sh`) package code into zips, upload to Lambda, and activate — clear separation between build (zip), release (deploy), and run (Lambda invocation). | ✅ Full |
| **VI. Processes** | All Lambdas are stateless. Each invocation is independent. No local filesystem state. The MCP server is explicitly stateless — no sessions between requests. | ✅ Full |
| **VII. Port binding** | API Gateway exposes HTTPS endpoints. The local FastAPI app binds to a configurable port. Services are self-contained. | ✅ Full |
| **VIII. Concurrency** | Lambda auto-scales horizontally. DynamoDB on-demand handles bursty traffic. No manual scaling configuration needed. | ✅ Full |
| **IX. Disposability** | Lambda functions start in <1 second. No graceful shutdown logic needed — AWS handles lifecycle. EventBridge schedules can be paused/resumed instantly. | ✅ Full |
| **X. Dev/prod parity** | The same code runs locally (FastAPI + `mcp_server.py`) and in production (Lambda). `demo/app.py` mirrors production behaviour for local testing. Gap: no formal staging environment — code goes from local to production. | ⚠️ Partial |
| **XI. Logs** | All Lambda functions write to CloudWatch Logs automatically. No log file management. Errors and tool call traces are logged as structured output. | ✅ Full |
| **XII. Admin processes** | One-time tasks (GTFS loading, infrastructure setup, data verification) are standalone scripts in `aws/scripts/`. They run in the same environment as the app. | ✅ Full |

**Key gap:** Factor X (dev/prod parity) is partially met. We have local development (FastAPI) and production (Lambda), but no formal staging environment. Code is tested locally and deployed directly to production. For a larger project, a staging AWS account with identical resources would close this gap.

---

## 5. Methodology

### 5.1 Division of Responsibilities

The team divided work by **data vertical** — each member owned one or more data domains end-to-end (source research → Lambda → DynamoDB schema → MCP tool):

| Member | Verticals | Additional Responsibilities |
|--------|-----------|----------------------------|
| Jakub | Bicing, Transit | MCP server, all AWS infrastructure scripts, demo app, deployment automation |
| Mark | Air Quality | AWS architecture design (DynamoDB schemas, IAM, EventBridge), MCP protocol research |
| Jia | Weather | Research presentation coordination, slide structure |
| José | UV, Pollen | Bedrock research, Bedrock chat app development, pivot from dead noise source |

### 5.2 Organization of Meetings

- **Weekly sync meetings** (in-person or online) to align on blockers, review progress, and redistribute tasks
- **Ad-hoc pairing sessions** for integration work (connecting verticals to MCP server, debugging AWS deployments)
- **Progress presentation** (May 15): forced a convergence point — all verticals had to be integrated and live by this date

### 5.3 Exchange of Ideas and Documentation

- **GitHub repository** as the single source of truth for code and documentation
- **Markdown documents** for all knowledge sharing: `TEAM_BRIEFING.md`, `PLAN.md`, `DEMO_NOTES.md`, per-vertical docs in `docs/`
- **Exploration scripts** (`bicing_exploration.py`, `tmb_api_exploration.py`, `gtfs_exploration.py`) committed to the repo so findings are reproducible
- Each vertical has a dedicated doc (`docs/MARK_AIR_QUALITY.md`, `docs/JIA_WEATHER.md`, `docs/JOSE_NOISE.md`) with API details, schema design, and task checklists

### 5.4 Working Environments

| Environment | Purpose | Infrastructure |
|-------------|---------|---------------|
| **Development** | Local coding and testing | FastAPI (`demo/app.py`) on localhost:8765, direct DynamoDB access via AWS credentials |
| **Production** | Live public deployment | Lambda + API Gateway + CloudFront + S3 (eu-west-1) |

No formal staging environment was used — testing was done locally against production DynamoDB tables (read-only for MCP tools, write-only for ingestion Lambdas). This was acceptable given the team size and project scope.

### 5.5 Tools Used

| Category | Tool | Purpose |
|----------|------|---------|
| Version control | Git + GitHub | Code collaboration, issue tracking |
| Cloud platform | AWS (eu-west-1) | All infrastructure |
| AI model | AWS Bedrock (Claude Haiku) | Chat agent reasoning |
| Database | DynamoDB (on-demand) | All data storage |
| Compute | AWS Lambda (Python 3.12) | Serverless functions |
| API exposure | API Gateway (HTTP API) | HTTPS endpoints |
| CDN/hosting | CloudFront + S3 | Static web app hosting |
| Scheduling | EventBridge | Lambda trigger schedules |
| Protocol | MCP (Model Context Protocol) | AI tool integration standard |
| Local dev | FastAPI + Uvicorn | Local web server |
| IDE | VS Code, PyCharm | Development |
| CLI | AWS CLI v2 | Infrastructure management |

---

## 6. Main Problems Encountered and Solutions

### 6.1 Coding Problems

| Problem | Impact | Solution |
|---------|--------|---------|
| **Sentilo noise API returns no live data** | Original noise vertical (José) was undeliverable — API returns HTTP 200 with `"found": false` for all queries | Pivoted to UV + Pollen verticals using reliable sources (currentuvindex.com, Open-Meteo CAMS) |
| **Bicing BSM API transient 503 errors** | Bicing data gaps during outages | Lambda implements exponential back-off (1s, 2s, 4s, 8s, 16s); DynamoDB serves slightly-stale data with `data_age_seconds` field |
| **`innerHTML +=` destroys event listeners** | Expandable tool blocks in the web UI stopped responding to clicks | Rewrote DOM construction to use `createElement`/`appendChild` exclusively |
| **Lambda Function URL 403 errors** | Chat API was inaccessible despite correct resource policy (account-level block) | Switched from Lambda Function URLs to API Gateway HTTP API — resolved immediately |
| **IAM 10-managed-policy limit** | Could not attach Bedrock permissions to the shared IAM user | Consolidated 9 managed policies into a single inline policy (`SmartCityAccess`) |
| **AgentCore Gateway requires SigV4** | Cannot be called from a browser directly | Chat Lambda calls MCP server directly (unauthenticated); AgentCore Gateway reserved for future Bedrock Agents SDK use |

### 6.2 Team Organization Problems

| Problem | Impact | Solution |
|---------|--------|---------|
| **Data source validation too late** | Time wasted building against dead APIs (Sentilo noise, CKAN beach water quality) | Lesson learned: always validate with a quick scan query before committing to a vertical |
| **Dependency on single AWS account holder** | All team members needed credentials from Jakub | Shared IAM user with least-privilege inline policy; credentials distributed securely |
| **Coordination overhead for integration** | Each vertical developed in isolation; integration required alignment on schemas and tool signatures | Central `dynamodb_schema.md` and `tool_signatures.py` as contracts; `TEAM_BRIEFING.md` as convergence document |

### 6.3 Services and Resources Problems

| Problem | Impact | Solution |
|---------|--------|---------|
| **DynamoDB hot partitions** | Early schema had overwrites on the same partition key | Redesigned with sort key on `updated_at` (timestamp) so each write creates a new item; TTL auto-cleans |
| **Bedrock model availability by region** | Claude models not available in all regions | Used `eu-north-1` for Bedrock during development, later switched to `eu-west-1` with `eu.anthropic.claude-haiku-4-5` |
| **Lambda cold starts** | First invocation of MCP server or chat Lambda takes 1–2 seconds | Acceptable for the use case; not a blocking issue at demo scale |

---

## 7. Services and Resources — Justification and Alternatives

### 7.1 AWS DynamoDB

**How the project benefits:** Sub-millisecond read latency (critical for MCP tools in live AI conversations), on-demand capacity (pay-per-request, effectively free at demo scale), built-in TTL for automatic data expiry, no server management.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| PostgreSQL (RDS) | Higher cost (always-on instance), more complex schema management for the simple key-value access patterns used |
| Redis (ElastiCache) | No persistence guarantees, higher cost for always-on cluster, overkill for hourly-updated data |
| S3 + Athena | Too slow for real-time tool responses (seconds vs milliseconds); better suited for batch analytics |

### 7.2 AWS Lambda

**How the project benefits:** Zero server management, automatic scaling, pay-per-invocation (free tier covers all demo usage), Python 3.12 runtime includes `boto3` — no dependency packaging needed.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| EC2 instances | Always-on cost, requires OS patching, manual scaling |
| ECS/Fargate | Overkill for short-lived functions; adds container management complexity |
| Google Cloud Functions | Would split infrastructure across providers; team had AWS credits and expertise |

### 7.3 AWS Bedrock (Claude Haiku)

**How the project benefits:** Managed API — no model hosting, billing, or auth management. Supports tool use (function calling) natively. Claude Haiku provides fast, cost-effective responses with strong reasoning. Integration with AWS IAM for security.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| OpenAI API (GPT-4) | External provider, separate billing, no AWS IAM integration — more operational complexity |
| Self-hosted LLM (Ollama/vLLM) | Requires GPU instances (expensive), model management, worse tool-use capability |
| Anthropic API (direct) | Similar to Bedrock but requires separate API key management and has no AWS integration |

### 7.4 MCP (Model Context Protocol)

**How the project benefits:** Build the server once; any compatible AI client (claude.ai, Claude Desktop, VS Code, future clients) gets city awareness without bespoke integration. Protocol is standardised (JSON-RPC 2.0), stateless, and transport-agnostic.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| Custom REST API | Each AI client would need bespoke integration code; no standard for tool discovery |
| OpenAI function calling (direct) | Locks tools to one model provider; no interoperability |
| LangChain tools | Framework-specific; requires the client to use LangChain — not a protocol |

### 7.5 AWS API Gateway

**How the project benefits:** Managed HTTPS endpoints with automatic TLS, throttling, and monitoring. HTTP API flavour is low-cost and low-latency. Direct Lambda integration with payload format 2.0.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| Lambda Function URLs | Simpler but hit account-level 403 blocks; less control over routing and CORS |
| Application Load Balancer | Higher base cost, designed for container/EC2 targets rather than Lambda |
| CloudFlare Workers | Would split infrastructure; no native AWS Lambda integration |

### 7.6 AWS CloudFront + S3

**How the project benefits:** Global CDN for the static web app with HTTPS. S3 hosting is near-zero cost. CloudFront provides edge caching and custom domain support.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| GitHub Pages | No custom API integration, no control over cache headers |
| Vercel/Netlify | External provider; adds deployment complexity for a single HTML file |
| Serving from Lambda | Unnecessary compute cost for static content |

### 7.7 EventBridge Schedules

**How the project benefits:** Cron-like scheduling fully managed by AWS. Triggers Lambda on precise intervals (5 min for Bicing, 1 hour for others). Can be paused/resumed with a single CLI command for cost control.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| CloudWatch Events (legacy) | EventBridge is the successor; same functionality with better console UX |
| Cron on EC2 | Requires always-on instance; defeats serverless model |
| Step Functions | Overkill for simple periodic invocation |

### 7.8 External Data Sources (Open Data BCN, Open-Meteo, Bicing GBFS, Transitous)

**How the project benefits:** All free, no API keys required, JSON responses, reliable uptime (except Sentilo). Open-Meteo provides global weather + pollen data with no rate limits. Transitous provides open-source transit routing for all of Europe.

**Alternatives considered:**
| Alternative | Reason Discarded |
|-------------|-----------------|
| Meteocat (Catalan weather service) | Requires API key application and approval process |
| Google Maps Directions API | Paid, requires billing account, closed-source routing |
| TMB live API (authenticated) | Rate-limited, requires registered app credentials |

---

## 8. Hours Invested and Project Deviation

### 8.1 Hours by Member and Task

| Task | Jakub | Mark | Jia | José | Total |
|------|-------|------|-----|------|-------|
| **Architectural design** | 12 | 8 | 3 | 4 | 27 |
| **Research & documentation** | 8 | 10 | 8 | 10 | 36 |
| **Data source exploration** | 6 | 5 | 4 | 8 | 23 |
| **Lambda development** | 10 | 6 | 5 | 8 | 29 |
| **MCP server development** | 15 | 3 | 2 | 3 | 23 |
| **Bedrock chat app** | 8 | 2 | 3 | 6 | 19 |
| **Web frontend** | 10 | 1 | 2 | 2 | 15 |
| **AWS infrastructure & deployment** | 14 | 4 | 2 | 3 | 23 |
| **Demo/presentation preparation** | 6 | 4 | 5 | 4 | 19 |
| **Meetings & coordination** | 6 | 6 | 6 | 6 | 24 |
| **Debugging & troubleshooting** | 8 | 4 | 3 | 6 | 21 |
| **Testing & verification** | 4 | 3 | 2 | 3 | 12 |
| **Written documentation** | 5 | 4 | 4 | 5 | 18 |
| **Total** | **112** | **60** | **49** | **68** | **289** |

### 8.2 Initial Hour Estimate vs Actual

| | Planned | Actual | Deviation |
|---|---------|--------|-----------|
| **Total project hours** | 240 | 289 | +49 (+20%) |
| **Per member (average)** | 60 | 72 | +12 |

### 8.3 Sources of Deviation

1. **Dead data sources** (+15h): Time spent researching, implementing, and then scrapping the noise vertical (Sentilo) and beach water quality (CKAN). The pivot to UV + Pollen required starting from scratch.

2. **AWS configuration issues** (+12h): IAM policy limits, Lambda Function URL 403s, Bedrock region availability, AgentCore Gateway SigV4 complexity — each required debugging with limited error messages.

3. **Scope expansion** (+12h): The Bedrock chat app and public deployment (CloudFront + S3) were added to the plan after the progress presentation, expanding scope beyond the original MCP-server-only deliverable.

4. **Integration work** (+10h): Connecting independently-developed verticals into a unified MCP server and chat app required schema alignment, tool signature negotiation, and end-to-end testing.

### 8.4 How the Team Could Have Deviated Less

1. **Validate data sources on day one** — A mandatory "data source audit" in the first week (one HTTP request per source, verify live data exists) would have avoided 15+ hours of wasted effort on dead APIs.

2. **Define tool contracts earlier** — A shared `tool_signatures.py` and `dynamodb_schema.md` agreed upon in week 1 would have reduced integration friction.

3. **Limit scope creep** — The Bedrock app was added mid-project. Deciding upfront whether the deliverable is "MCP server only" or "MCP server + application" would have allowed better time allocation.

4. **Use a staging environment** — Testing against production DynamoDB worked but slowed debugging. A separate set of test tables would have allowed faster iteration.

5. **More balanced workload** — Jakub carried a disproportionate share (112h vs team average of 72h). Earlier delegation of infrastructure tasks to other members would have balanced the load and reduced single-point-of-failure risk.

---

## Appendix A: Repository Structure

```
barcelona-smart-city/
├── mcp_server.py                  # MCP server (11 tools, Lambda handler)
├── transit_route_tool.py          # Transitous routing helper
├── requirements.txt               # Python dependencies
├── aws/
│   ├── setup.sh                   # Create all DynamoDB tables + IAM roles
│   ├── deploy.sh                  # Package + deploy Lambdas + API Gateway
│   ├── pause.sh                   # Pause EventBridge schedules
│   ├── teardown.sh                # Delete all AWS resources
│   ├── lambdas/
│   │   ├── bicing_ingest/         # Every 5 min → BicingStations
│   │   ├── air_quality_ingest/    # Every 1 hr → AirQualityReadings
│   │   ├── weather_ingest/        # Every 1 hr → WeatherData
│   │   ├── uv_ingest/             # Every 1 hr → UVData
│   │   ├── pollen_ingest/         # Every 1 hr → PollenData
│   │   └── chat/                  # Bedrock agentic loop
│   ├── scripts/
│   │   ├── load_gtfs.py           # One-time GTFS load (3,453 stops)
│   │   └── verify_data.py         # Data verification
│   └── policies/                  # IAM policy JSON files
├── webapp/
│   └── index.html                 # Production web UI (S3 + CloudFront)
├── demo/
│   ├── app.py                     # Local dev: FastAPI + Bedrock + Leaflet map
│   ├── index.html                 # Local demo UI
│   └── run.sh                     # Start local server
├── gtfs/                          # TMB GTFS static feed
└── docs/                          # Per-vertical documentation
```

## Appendix B: MCP Tools Reference

| # | Tool | Input | Output |
|---|------|-------|--------|
| 1 | `get_bicing` | lat, lon, max_results, max_radius_m | Nearest stations with bike/dock counts |
| 2 | `get_bicing_history` | station_id, hours | Snapshots over time for trend analysis |
| 3 | `get_transit_nearby` | lat, lon, max_results | Metro/bus stops with route names |
| 4 | `get_transit_route` | origin_lat/lon, dest_lat/lon | Multi-leg journey with lines and durations |
| 5 | `get_air_quality` | lat, lon, pollutants | Latest readings + WHO status labels |
| 6 | `get_air_quality_history` | station_id, pollutant, hours | Historical readings for trends |
| 7 | `get_weather` | — | Current temperature, wind, precipitation, conditions |
| 8 | `get_uv_index` | lat, lon | Live UVI + burn time + SPF recommendation |
| 9 | `get_uv_history` | hours | Hourly UVI readings |
| 10 | `get_pollen` | lat, lon | 5-species pollen levels + classifications |
| 11 | `get_pollen_history` | species, hours | Historical pollen readings |
