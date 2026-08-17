# Dynatrace Terraform E2E

## What this is

A **Terraform-only** Dynatrace config project for a beginner SRE. It manages monitoring configuration (zones, alerts, metric events, SLOs, synthetics, dashboards, Grail log rules, tags, Slack/PagerDuty) the way a JD for “Dynatrace + Terraform observability” expects.

It does **not** install OneAgent. Agents, host groups at install time, and “accept this host” for brand-new machines stay outside Terraform. This repo documents that boundary clearly.

## Why it matters

Dynatrace without IaC drifts: someone clicks a dashboard, another person edits an alert, noise goes up, RCA gets slower. Terraform keeps **app + infra monitoring configs** reviewable in Git, with **dev relaxed / prod strict** thresholds for alert tuning.

## Quick start (you run these)

1. Pick an apply root: `environments/dev` (or staging / production).
2. Copy `terraform.tfvars.example` → `terraform.tfvars` and replace `REPLACE_ME`.
3. `terraform init` then `terraform plan` (do not apply until tokens and scopes are real).

See `docs/JD-MAPPING.md` and `docs/RCA-RUNBOOK.md`.

## JD → Terraform mapping

| JD requirement | Where it lives in this repo |
|---|---|
| Configure/manage app + infra monitoring with Dynatrace | `modules/management_zones`, `modules/metric_events`, `modules/tagging` |
| Leverage DT for observability and performance | `modules/slo`, `modules/dashboards`, `modules/metric_events` |
| RCA efficiently using Dynatrace tools | `docs/RCA-RUNBOOK.md` + problem → metric events → Grail logs |
| Design/create/maintain dashboards, alerts, monitoring configs | `modules/dashboards`, `modules/alerting`, `modules/metric_events` |
| Tune alerting for performance + reduced noise | Env thresholds in `environments/*/main.tf` + delay tiers in `modules/alerting` |
| Onboard servers/apps (tags, zones, host groups naming; OneAgent outside TF) | `modules/tagging`, `modules/management_zones`; see **Onboarding boundary** below |
| Synthetic Monitoring | `modules/synthetics` (`dynatrace_http_monitor`) |
| Dynatrace Grail for log management and analytics | `modules/grail_logs`; see **Grail: what TF can/can't do** |
| Maintain DT configs with Terraform | Entire repo; apply roots under `environments/` |
| Network-related monitoring (good to have) | `modules/metric_events` → `builtin:host.net.errorRate` + dashboard tile |
| Reliability via proactive monitoring + incident wiring | `modules/synthetics` + `modules/notifications` (Slack + PagerDuty) |

## Project layout

```
dynatrace-terraform-e2e/
  README.md
  versions.tf / providers.tf / variables.tf / locals.tf / terraform.tfvars.example
  .gitignore
  modules/
    management_zones/   # dynatrace_management_zone_v2 (patched ~> 1.55 schema)
    alerting/           # 4 tiers + delays (noise reduction)
    metric_events/      # traffic/error/latency/cpu/mem/jvm/restarts/network
    slo/                # availability + latency SLO v2
    synthetics/         # HTTP monitors
    dashboards/         # dynatrace_json_dashboard
    grail_logs/         # log_buckets + log_processing (+ optional log_grail)
    tagging/            # autotag_v2 + host_naming
    notifications/      # Slack + PagerDuty
  environments/
    dev/                # relaxed thresholds, Slack only
    staging/            # mid thresholds, PD for high
    production/         # strict thresholds, PD critical+high
  docs/
    JD-MAPPING.md
    RCA-RUNBOOK.md
    MODULE-GUIDE.md     # deep per-module guide (what / when / on-call)
```

### What each folder does (module map)

| Path | What it does | When you edit it | On-call meaning |
|---|---|---|---|
| `modules/management_zones` | One zone per team×env for SERVICE/PG/HOST | New team or zone rules | Scopes Problems so you only see your team |
| `modules/alerting` | Four severity tiers with delays | Delay / which env pages | Noise control before notify |
| `modules/metric_events` | Eight metric-threshold Problem openers | Thresholds in env `services` map | Turns symptoms into Problems |
| `modules/slo` | Availability + latency SLO v2 | Targets in env `services` map | Error-budget view |
| `modules/synthetics` | HTTP health from geo locations | Health URL / geos / outage policy | Outside-in “is it up?” |
| `modules/dashboards` | Shared JSON SRE overview | Tiles / RCA markdown | First visual during incident |
| `modules/grail_logs` | Log bucket route + JSON PARSE | Matchers / processors | Structured logs for RCA |
| `modules/tagging` | Autotag + host naming from host group | Naming convention / teams | Tags that zones filter on |
| `modules/notifications` | Slack + PagerDuty on alert profiles | Webhooks / PD keys / messages | Who gets paged vs Slack |
| `environments/dev` | Apply root; relaxed thresholds | Dev tuning / Slack only | Safe place to learn apply |
| `environments/staging` | Apply root; mid thresholds; PD high | Pre-prod alert tuning | Load-test friendly |
| `environments/production` | Apply root; strict; PD critical+high | Prod SLOs / pages | Real on-call wiring |
| Root `*.tf` + `.gitignore` | Docs contract + secrets ignore | Rare bumps / never commit tokens | Not an apply root |

Deeper per-module tables (resources, inputs, outputs): [docs/MODULE-GUIDE.md](docs/MODULE-GUIDE.md).

**Git tip:** a green **U** in the IDE source-control view means **Untracked** (not committed yet). Normal for a new repo until you add/commit.

### Module connection (apply reasoning order)

```
tagging (+ OneAgent host groups outside TF)
  → management_zones (needs tags at runtime)
    → alerting (needs zone_ids in Terraform)
      → notifications (needs profile_ids)
metric_events / slo / synthetics / dashboards / grail_logs
  (parallel once provider works; no hard TF dep on zones)
```
## Multi-env alert tuning (beginner view)

| Env | Error rate example (payment) | Latency P99 | PagerDuty | Alert delays |
|---|---|---|---|---|
| Dev | 10% (relaxed) | 2000 ms | Off | Warning/info only |
| Staging | 1% | 800 ms | High tier | High 2m + warning/info |
| Production | 0.1% | 300 ms | Critical + high | Critical 0m, high 2m, warning 5m, info 15m |

Same modules everywhere. Only the **services map** and which alerting tiers create resources change.

## Onboarding boundary (TF vs not TF)

| Step | Terraform? | How |
|---|---|---|
| Install OneAgent on host / K8s operator | **No** | Ansible, Helm, cloud-init, SSM |
| Set host group at install | **No** | `oneagentctl --set-host-group=payments-production` (or operator arg) |
| Host naming rules in UI | **Yes** | `modules/tagging` → `dynatrace_host_naming` |
| Auto-tags from host group | **Yes** | `modules/tagging` → `dynatrace_autotag_v2` |
| Management zones by team/env tags | **Yes** | `modules/management_zones` |
| Per-host monitoring mode toggle | Rarely | `dynatrace_host_monitoring` needs `host_id` after discovery — not in default stack |
| Accept / license new hosts | Process | Usually automatic after agent connects; document in CMDB |

## Grail: what TF can / can't do

| Can with Terraform (this repo) | Cannot / limited |
|---|---|
| `dynatrace_log_buckets` — route matcher → retention bucket | Ad-hoc DQL notebooks and saved explorations as first-class TF (use UI / Monaco / Docs) |
| `dynatrace_log_processing` — PARSE / FIELDS_ADD pipelines | Full security context IAM for every Grail table (partial resources exist; not all wired here) |
| Optional `dynatrace_log_grail` activation (deprecated one-shot) | Installing log ingest agents / OneAgent log modules |
| Matcher strings that look like DQL phrases | Replacing operators investigating with Notebooks |

Provider pin: `dynatrace-oss/dynatrace` **~> 1.55**. Schema patterns match the patched ExplainProjects module (no broken `attribute_conditions` duplicates, no old metric_events shapes).

## Token scopes (minimum for this stack)

| Scope | Why |
|---|---|
| `settings.read` / `settings.write` | Zones, alerting, metric events, SLO, tags, Grail log settings |
| `ReadConfig` / `WriteConfig` | `dynatrace_json_dashboard`, `dynatrace_host_naming` |
| Synthetic write (tenant naming varies) | `dynatrace_http_monitor` |
| `entities.read` | Helpful for lookups / some host settings |

## Secrets

- Use `terraform.tfvars` locally (gitignored) from `*.tfvars.example`.
- Or enable `environments/*/secrets.tf.example` with AWS Secrets Manager.
- Never commit real `dt_api_token`, Slack webhooks, or PagerDuty keys.

## Shared tenant tip

If **dev / staging / production share one Dynatrace tenant**, apply `modules/tagging` from **one** environment only (or a dedicated `shared/` root). Tag *keys* like `environment` and `team` are tenant-global; three separate applies fight over the same objects. Zones named `team-env` and metric events can coexist on one tenant.

## Schema gotchas already fixed

| Old (broken) | Current (~> 1.55) |
|---|---|
| Two `attribute_conditions` blocks | One wrapper + nested `condition { key, operator, tag }` |
| Metric event top-level `event_type` | Inside `event_template { }` |
| Flat dimension conditions | `dimension_filter { filter { } }` |
| Alert severity `ERROR` / `SLOWDOWN` | `ERRORS` / `PERFORMANCE` |
| SLO `description` | `custom_description` + required `filter` |

## Related docs

| Doc | Purpose |
|---|---|
| [docs/MODULE-GUIDE.md](docs/MODULE-GUIDE.md) | Detailed per-module map (tree meaning + on-call) |
| [docs/JD-MAPPING.md](docs/JD-MAPPING.md) | Bullet-by-bullet JD coverage |
| [docs/RCA-RUNBOOK.md](docs/RCA-RUNBOOK.md) | How these resources help RCA |
# t2
