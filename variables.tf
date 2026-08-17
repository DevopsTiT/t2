##############################################################################
# Root variable catalog (mirror of what environments pass into modules).
# Environments redefine these locally; this file documents the contract.
##############################################################################

variable "environment" {
  type        = string
  description = "dev | staging | production"
}

variable "dt_env_url" {
  type        = string
  sensitive   = true
  description = "Dynatrace tenant URL, e.g. https://abc12345.live.dynatrace.com"
}

variable "dt_api_token" {
  type        = string
  sensitive   = true
  description = "API token with settings.read/write, ReadConfig/WriteConfig, synthetic.write, entities.read as needed"
}

variable "pagerduty_integration_keys" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = "Map of team name → PagerDuty Events API v2 integration key"
}

variable "slack_webhook_urls" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = "Map of team name → Slack incoming webhook URL"
}

variable "synthetic_locations" {
  type        = list(string)
  description = "Dynatrace synthetic geolocation IDs"
  default     = ["GEOLOCATION-6F55B7E4B5E7A52F"] # Tokyo placeholder
}

variable "services" {
  description = "Per-service thresholds (dev relaxed / prod strict). All examples are JVM services."
  type = map(object({
    team                   = string
    slo_target             = number
    health_check_url       = string
    traffic_min_rps        = number
    error_rate_alert       = number
    latency_p99_ms         = number
    cpu_saturation_pct     = number
    memory_usage_pct       = number
    jvm_heap_pct           = number
    pod_restart_threshold  = number
    network_error_rate_pct = number
  }))
  default = {}
}

variable "enable_grail_activation" {
  type        = bool
  default     = false
  description = "If true, manage dynatrace_log_grail activation (one-time / often already done)."
}

variable "dashboard_owner" {
  type        = string
  default     = "terraform-sre"
  description = "Owner string shown on dynatrace_json_dashboard metadata"
}
