# RCA Runbook (Dynatrace + This Terraform Stack)

## What RCA means here

**RCA** (root cause analysis) is finding *why* users hurt, not just *that* an alert fired. Dynatrace helps when problems, metrics, traces (PurePath), synthetics, and Grail logs line up. This Terraform stack pre-wires those signals.

## Decision tree (on-call)

```
Alert / Slack / PagerDuty page
  │
  ├─ Synthetic failed only?
  │    → Check URL, DNS, cert, ALB; compare with service error rate
  │
  ├─ Traffic drop event?
  │    → Upstream (ALB/DNS/deploy) before digging JVM
  │
  ├─ Error rate up?
  │    → Problem → impacted service → PurePath failing calls
  │    → Grail: filter parsed http.status >= 500 (log_processing rule)
  │
  ├─ Latency / PERFORMANCE warning?
  │    → Dependency slow? CPU/heap? GC? Downstream DB
  │
  ├─ CPU / memory / JVM heap RESOURCE?
  │    → Scale or leak; confirm pod restarts event
  │
  ├─ Network errorRate?
  │    → Node NICs, SG, CNI, noisy neighbor
  │
  └─ Still unclear?
         → Management zone for team → entity timeline → recent deploy tag
```

## How each Terraform piece helps

| Resource from this project | How it helps RCA |
|---|---|
| Management zones | Limits the blast radius view to one team/env |
| Alerting delays | Cuts transient blips so pages are more trustworthy |
| Traffic drop event | Catches silent outages when error rate stays “fine” |
| Error / latency events | Points at symptom class (fail vs slow) |
| CPU / mem / JVM / restarts | Separates app bug vs resource pressure |
| Network errorRate | Flags infra path before blaming Java code |
| SLOs + burn rate | Tells you if this is burning budget fast |
| Synthetics | Separates “users can’t reach us” from “in-cluster only” |
| Dashboard | Single screen for failure rate, traffic, network |
| Grail bucket + processing | Faster log filter on ERROR / parsed status |
| Slack / PagerDuty | Gets the right severity to the right channel |

## Happy path (production payment-service)

1. PagerDuty: `payments-production-critical` or high.
2. Open Problem URL from the notification message.
3. Confirm management zone `payments-production`.
4. Check whether traffic drop, error rate, or synthetic failed first (timeline).
5. Open PurePath for failing requests.
6. In Grail Logs, use fields from `tf-production-parse-http-json` if present.
7. Fix (rollback > flag off > scale), then confirm synthetic green and error rate down.

## Common mistakes

| Mistake | Better approach |
|---|---|
| Jumping straight to JVM heap on every page | Check traffic + synthetic first |
| Treating every warning Slack as a SEV1 | Respect tier delays and PD vs Slack routing |
| Editing alerts in the UI during an incident | Hotfix carefully, then PR the Terraform change |
| Forgetting OneAgent is outside TF | Missing host = install/config issue, not a bad zone |
