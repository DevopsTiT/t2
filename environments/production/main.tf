terraform {
  required_version = ">= 1.5.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.55"
    }
  }
}

provider "dynatrace" {
  dt_env_url   = var.dt_env_url
  dt_api_token = var.dt_api_token
}

variable "dt_env_url" {
  type      = string
  sensitive = true
}

variable "dt_api_token" {
  type      = string
  sensitive = true
}

variable "pagerduty_integration_keys" {
  type      = map(string)
  sensitive = true
  default   = {}
}

variable "slack_webhook_urls" {
  type      = map(string)
  sensitive = true
  default   = {}
}

variable "synthetic_locations" {
  type = list(string)
  default = [
    "GEOLOCATION-6F55B7E4B5E7A52F", # Tokyo
    "GEOLOCATION-D15FBAABA11A2D7D", # Singapore
  ]
}

variable "enable_grail_activation" {
  type    = bool
  default = false
}

variable "dashboard_owner" {
  type    = string
  default = "terraform-sre"
}

locals {
  environment = "production"

  # Production: STRICTEST thresholds + PD oncall
  services = {
    "payment-service" = {
      team                   = "payments"
      slo_target             = 99.9
      health_check_url       = "https://payment.example.com/actuator/health"
      traffic_min_rps        = 10
      error_rate_alert       = 0.1
      latency_p99_ms         = 300
      cpu_saturation_pct     = 70
      memory_usage_pct       = 75
      jvm_heap_pct           = 70
      pod_restart_threshold  = 2
      network_error_rate_pct = 0.5
    }
    "order-service" = {
      team                   = "orders"
      slo_target             = 99.5
      health_check_url       = "https://orders.example.com/actuator/health"
      traffic_min_rps        = 5
      error_rate_alert       = 0.5
      latency_p99_ms         = 500
      cpu_saturation_pct     = 80
      memory_usage_pct       = 80
      jvm_heap_pct           = 75
      pod_restart_threshold  = 2
      network_error_rate_pct = 1.0
    }
    "notification-service" = {
      team                   = "notifications"
      slo_target             = 99.0
      health_check_url       = "https://notify.example.com/actuator/health"
      traffic_min_rps        = 3
      error_rate_alert       = 1.0
      latency_p99_ms         = 1000
      cpu_saturation_pct     = 80
      memory_usage_pct       = 80
      jvm_heap_pct           = 75
      pod_restart_threshold  = 2
      network_error_rate_pct = 1.0
    }
  }

  teams = toset([for s in values(local.services) : s.team])
}

module "management_zones" {
  source      = "../../modules/management_zones"
  environment = local.environment
  teams       = local.teams
}

module "alerting" {
  source      = "../../modules/alerting"
  environment = local.environment
  teams       = local.teams
  zone_ids    = module.management_zones.zone_ids
}

module "metric_events" {
  source      = "../../modules/metric_events"
  environment = local.environment
  services    = local.services
}

module "slo" {
  source      = "../../modules/slo"
  environment = local.environment
  services    = local.services
}

module "synthetics" {
  source              = "../../modules/synthetics"
  environment         = local.environment
  services            = local.services
  synthetic_locations = var.synthetic_locations
}

module "dashboards" {
  source        = "../../modules/dashboards"
  environment   = local.environment
  owner         = var.dashboard_owner
  service_names = keys(local.services)
}

module "grail_logs" {
  source                  = "../../modules/grail_logs"
  environment             = local.environment
  enable_grail_activation = var.enable_grail_activation
}

module "tagging" {
  source      = "../../modules/tagging"
  environment = local.environment
  teams       = local.teams
}

module "notifications" {
  source                     = "../../modules/notifications"
  environment                = local.environment
  pagerduty_integration_keys = var.pagerduty_integration_keys
  slack_webhook_urls         = var.slack_webhook_urls
  critical_profile_ids       = module.alerting.critical_profile_ids
  high_profile_ids           = module.alerting.high_profile_ids
  warning_profile_ids        = module.alerting.warning_profile_ids
  info_profile_ids           = module.alerting.info_profile_ids
}

output "management_zone_ids" {
  value = module.management_zones.zone_ids
}

output "dashboard_id" {
  value = module.dashboards.dashboard_id
}

output "synthetic_monitor_ids" {
  value = module.synthetics.monitor_ids
}
