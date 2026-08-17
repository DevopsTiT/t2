# JD Mapping

Maps each JD bullet to concrete Terraform modules and what “done” looks like for a beginner SRE.

## Coverage table

| JD bullet | Module / file | Terraform resources | Done means |
|---|---|---|---|
| Configure/manage app + infra monitoring | `management_zones`, `metric_events`, `tagging` | `dynatrace_management_zone_v2`, `dynatrace_metric_events`, `dynatrace_autotag_v2` | Services/hosts land in team zones; signals fire on thresholds |
| Observability and performance | `slo`, `dashboards`, `metric_events` | `dynatrace_slo_v2`, `dynatrace_json_dashboard` | SLOs + overview dashboard exist per env |
| RCA with Dynatrace tools | `docs/RCA-RUNBOOK.md` + events/logs | Metric events + Grail processing | Problem → signal → log fields path documented |
| Dashboards, alerts, monitoring configs | `dashboards`, `alerting`, `metric_events` | `dynatrace_json_dashboard`, `dynatrace_alerting`, events | Git is source of truth for these objects |
| Tune alerting / reduce noise | `environments/*/main.tf`, `alerting` | Profile delays + per-env thresholds | Dev noisy-tolerant; prod strict + delayed tiers |
| Onboard servers/apps | `tagging`, `management_zones` | Autotag, host naming, zones | Tags/zones ready; OneAgent install still ops-owned |
| Synthetic Monitoring | `synthetics` | `dynatrace_http_monitor` | HTTP health checks every 5 minutes |
| Grail log management and analytics | `grail_logs` | `dynatrace_log_buckets`, `dynatrace_log_processing`, optional `dynatrace_log_grail` | Error routing + JSON parse rules applied |
| Maintain DT configs with Terraform | whole repo | all | `plan`/`apply` per environment root |
| Network monitoring (good to have) | `metric_events`, dashboard tile | `builtin:host.net.errorRate` | Network error signal + tile |
| Proactive monitoring + incident wiring | `synthetics`, `notifications` | HTTP monitors, Slack, PagerDuty | Critical/high → PD; warning/info → Slack |

## Threshold philosophy (interview soundbite)

Dev answers “is the pipeline wired?” Staging answers “does it survive load?” Production answers “is the customer hurting?” Thresholds encode that; Terraform keeps them reviewable.
