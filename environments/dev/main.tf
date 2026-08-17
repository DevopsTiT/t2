terraform {
  required_version = ">= 1.5.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.55"
    }
  }

  # Optional remote state — replace or use local for learning
  # backend "s3" {
  #   bucket = "company-terraform-state-dev"
  #   key    = "dynatrace/dev/terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
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
  type    = list(string)
  default = ["GEOLOCATION-6F55B7E4B5E7A52F"]
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
  environment = "dev"

  # Dev: RELAXED thresholds (JD alert tuning)
  services = {
    "payment-service" = {
      team                   = "payments"
      slo_target             = 90.0
      health_check_url       = "https://payment.dev.example.com/actuator/health"
      traffic_min_rps        = 0
      error_rate_alert       = 10.0
      latency_p99_ms         = 2000
      cpu_saturation_pct     = 90
      memory_usage_pct       = 85
      jvm_heap_pct           = 85
      pod_restart_threshold  = 5
      network_error_rate_pct = 5.0
    }
    "order-service" = {
      team                   = "orders"
      slo_target             = 90.0
      health_check_url       = "https://orders.dev.example.com/actuator/health"
      traffic_min_rps        = 0
      error_rate_alert       = 10.0
      latency_p99_ms         = 2000
      cpu_saturation_pct     = 90
      memory_usage_pct       = 85
      jvm_heap_pct           = 85
      pod_restart_threshold  = 5
      network_error_rate_pct = 5.0
    }
    "notification-service" = {
      team                   = "notifications"
      slo_target             = 90.0
      health_check_url       = "https://notify.dev.example.com/actuator/health"
      traffic_min_rps        = 0
      error_rate_alert       = 10.0
      latency_p99_ms         = 3000
      cpu_saturation_pct     = 90
      memory_usage_pct       = 85
      jvm_heap_pct           = 85
      pod_restart_threshold  = 5
      network_error_rate_pct = 5.0
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
  pagerduty_integration_keys = var.pagerduty_integration_keys # empty in dev
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
