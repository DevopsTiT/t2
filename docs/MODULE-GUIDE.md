# Module Guide

Beginner map of every folder under `modules/` and how `environments/*` wires them. Read this when the tree screenshot feels too thin.

## Git status tip

In Cursor / VS Code source control, a green **U** means **Untracked**: Git sees the file but it is not committed yet. That is normal for a new learning repo until you `git add` and commit.

## How an environment uses modules

Each apply root (`environments/dev`, `staging`, `production`) is a full Terraform root. It:

1. Sets provider + secrets (`dt_env_url`, `dt_api_token`).
2. Defines `local.services` (thresholds differ by env).
3. Derives `local.teams` from those services.
4. Calls the nine modules below.

```
environments/<env>/main.tf
  ├─ module.management_zones  → zone_ids
  │       └─ module.alerting  → profile_ids
  │               └─ module.notifications  (Slack / PagerDuty)
  ├─ module.metric_events     (uses services map)
  ├─ module.slo               (uses services map)
  ├─ module.synthetics        (uses services + geo IDs)
  ├─ module.dashboards        (uses service name list)
  ├─ module.grail_logs        (log bucket + processing)
  └─ module.tagging           (autotag + host naming)
```

**Logical apply order (what to reason about first):** tagging + management zones → alerting → notifications → metric events / SLO / synthetics / dashboards / Grail. Terraform only *enforces* the arrows above (zone → alert → notify).

---

## modules/management_zones

| Topic | Detail |
|---|---|
| What it is | Creates one management zone per team for the current environment. |
| Resource | `dynatrace_management_zone_v2` |
| When to edit | New team name, or change which entity types (SERVICE / PROCESS_GROUP / HOST) belong in the zone. |
| On-call / JD meaning | Scopes Problems and dashboards so payments on-call does not drown in orders noise. |
| Inputs | `environment`, `teams` |
| Outputs | `zone_ids`, `zone_names` |
| Depends on (runtime) | Tags `team` and `environment` already on entities (from OneAgent host group + tagging module). |

Zone name pattern: `{team}-{environment}` (example: `payments-production`).

---

## modules/alerting

| Topic | Detail |
|---|---|
| What it is | Four alerting *profiles* (tiers) per team, tied to a management zone. |
| Resource | `dynatrace_alerting` |
| When to edit | Delay minutes, which severities page, or which envs create critical/high. |
| On-call / JD meaning | Noise reduction: delay and severity decide who wakes up vs who gets Slack. |

| Tier | Severity | Delay | Environments that create it |
|---|---|---|---|
| critical | AVAILABILITY | 0 min | production only |
| high | ERRORS | 2 min | production + staging |
| warning | PERFORMANCE | 5 min | all |
| info | RESOURCE_CONTENTION + CUSTOM_ALERT | 15 min | all |

| Topic | Detail |
|---|---|
| Inputs | `environment`, `teams`, `zone_ids` |
| Outputs | `critical_profile_ids`, `high_profile_ids`, `warning_profile_ids`, `info_profile_ids` |
| Depends on (TF) | `module.management_zones.zone_ids` |

---

## modules/metric_events

| Topic | Detail |
|---|---|
| What it is | Static-threshold metric events per service (the “custom alerts” that open Problems). |
| Resource | `dynatrace_metric_events` (eight kinds) |
| When to edit | Thresholds live in `environments/*/main.tf` `local.services`. Change HCL here only for new metric keys or event shapes. |
| On-call / JD meaning | Turns SLO symptoms into actionable Problems (traffic, errors, latency, CPU, mem, JVM, restarts, network). |

| Event name | Metric key (built-in) | Typical symptom |
|---|---|---|
| traffic_drop | `builtin:service.requestCount.server` | Sudden quiet / bad deploy / DNS |
| error_rate | `builtin:service.errors.server.rate` | 5xx spike |
| latency_p99 | `builtin:service.response.time:percentile(99)` | Slow user path (threshold in µs) |
| cpu_saturation | `builtin:process.cpu.usage` | Hot process |
| memory_usage | `builtin:process.memory.usage` | OOM risk |
| jvm_heap | `builtin:process.memory.jvm.heapUtilization` | Heap pressure |
| pod_restarts | `builtin:kubernetes.workload.pods.restarts` | CrashLoop / OOMKill |
| network_error_rate | `builtin:host.net.errorRate` | Node / path network pain |

Traffic drop is skipped when `traffic_min_rps` is `0` (dev pattern).

---

## modules/slo

| Topic | Detail |
|---|---|
| What it is | Availability + latency SLO v2 objects per service. |
| Resource | `dynatrace_slo_v2` |
| When to edit | Target % and latency budget via `slo_target` / `latency_p99_ms` in services map; edit expressions only if metric math changes. |
| On-call / JD meaning | Error-budget view for “are we burning reliability?” — not every spike is a page. |
| Inputs | `environment`, `services` (team, slo_target, latency_p99_ms) |
| Outputs | `availability_slo_ids`, `latency_slo_ids` |

---

## modules/synthetics

| Topic | Detail |
|---|---|
| What it is | HTTP health monitors from Dynatrace synthetic locations. |
| Resource | `dynatrace_http_monitor` |
| When to edit | Health URL, geo IDs, outage policy, body pattern (`"status":"UP"`). |
| On-call / JD meaning | Outside-in check: “is the URL up from Tokyo?” even if in-cluster metrics look fine. |
| Inputs | `environment`, `services`, `synthetic_locations` |
| Outputs | `monitor_ids` |
| Tags set | team, environment, service, managed-by=terraform |

---

## modules/dashboards

| Topic | Detail |
|---|---|
| What it is | One shared JSON SRE overview dashboard per environment. |
| Resource | `dynatrace_json_dashboard` |
| When to edit | Tile metrics, layout, markdown RCA tips, owner string. |
| On-call / JD meaning | Single pane for failure rate, request count, network errors + short RCA path. |
| Token note | Needs `ReadConfig` + `WriteConfig` (classic Config API). |
| Inputs | `environment`, `owner`, `service_names` |
| Outputs | `dashboard_id` |

Tiles today: Header, Failure rate by service, Request count, Host network error rate, Markdown RCA tips.

---

## modules/grail_logs

| Topic | Detail |
|---|---|
| What it is | Log routing into a Grail bucket + a JSON field-parsing pipeline. |
| Resources | `dynatrace_log_buckets`, `dynatrace_log_processing`, optional `dynatrace_log_grail` |
| When to edit | Matcher phrases, PARSE rule, bucket name, or `enable_grail_activation`. |
| On-call / JD meaning | Makes ERROR/Exception logs searchable with structured `http.status` / path / service fields. |
| Does not do | Ad-hoc Notebooks, installing log agents, full Grail IAM. |

Keep `enable_grail_activation=false` unless you knowingly need the one-shot activation resource.

---

## modules/tagging

| Topic | Detail |
|---|---|
| What it is | Auto-tag keys + host naming from host-group conventions. |
| Resources | `dynatrace_autotag_v2` (environment, team, managed-by), `dynatrace_host_naming` |
| When to edit | Host-group naming convention, team list, host name format. |
| On-call / JD meaning | Without consistent tags, zones and filters fail — RCA becomes “find the host by guess”. |
| Outside TF | Creating the host group itself: OneAgent `--set-host-group={team}-{environment}`. |
| Shared tenant tip | Apply tagging from **one** env only if all envs share one Dynatrace tenant (tag keys are global). |

---

## modules/notifications

| Topic | Detail |
|---|---|
| What it is | Wires alerting profiles to Slack and PagerDuty. |
| Resources | `dynatrace_pager_duty_notification`, `dynatrace_slack_notification` |
| When to edit | Channel names, message templates, which tiers go to PD vs Slack. |
| On-call / JD meaning | Critical/high → page; warning/info → Slack (less sleep disruption). |

| Channel | Wired from profiles | Typical env |
|---|---|---|
| PagerDuty critical | `critical_profile_ids` | production (profiles exist there) |
| PagerDuty high | `high_profile_ids` | staging + production |
| Slack warning | `warning_profile_ids` | all (if webhook map set) |
| Slack info | `info_profile_ids` | all (if webhook map set) |

Empty `pagerduty_integration_keys` in dev means no PD resources (by design).

---

## Root files (not under modules/)

| Path | Purpose | When to edit |
|---|---|---|
| `versions.tf` | Documents provider pin `dynatrace ~> 1.55` + optional AWS | Rarely; bump after validating schema |
| `providers.tf` | Commented stub; real provider is in `environments/*` | Do not treat as apply root |
| `variables.tf` | Contract catalog for services / secrets | When adding a new service field |
| `locals.tf` | Example teams / host-group pattern docs | Teaching reference |
| `terraform.tfvars.example` | Template for secrets | Copy → `terraform.tfvars` (gitignored) |
| `.gitignore` | Blocks state, tfvars, `.terraform/` | Keep secrets out of Git |
| `environments/*/main.tf` | **Real apply root** + thresholds | Most day-to-day tuning |
| `docs/JD-MAPPING.md` | JD bullet → module | Interview / coverage |
| `docs/RCA-RUNBOOK.md` | How resources help RCA | On-call practice |
| `docs/MODULE-GUIDE.md` | This file | Tree / module deep dive |

---

## Related files

| File | Role |
|---|---|
| [../README.md](../README.md) | Project overview + module map |
| [JD-MAPPING.md](JD-MAPPING.md) | Job-description coverage |
| [RCA-RUNBOOK.md](RCA-RUNBOOK.md) | Problem → metrics → logs path |
