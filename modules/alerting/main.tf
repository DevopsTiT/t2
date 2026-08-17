# Alerting profiles: four severity tiers with delays (noise reduction).
# critical=prod only; high=prod+staging; warning/info=all envs.
# Feeds modules/notifications via profile ID outputs.

terraform {
  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.55"
    }
  }
}

variable "environment" {
  type = string
}

variable "teams" {
  type = set(string)
}

variable "zone_ids" {
  type        = map(string)
  description = "team → management zone id"
}

# Tier 1 CRITICAL — AVAILABILITY, 0 min delay — production only
resource "dynatrace_alerting" "critical" {
  for_each        = var.environment == "production" ? var.teams : toset([])
  name            = "${each.value}-${var.environment}-critical"
  management_zone = var.zone_ids[each.value]
  rules {
    rule {
      include_mode     = "INCLUDE_ALL"
      severity_level   = "AVAILABILITY"
      delay_in_minutes = 0
    }
  }
}

# Tier 2 HIGH — ERRORS, 2 min delay — production + staging
resource "dynatrace_alerting" "high" {
  for_each        = contains(["production", "staging"], var.environment) ? var.teams : toset([])
  name            = "${each.value}-${var.environment}-high"
  management_zone = var.zone_ids[each.value]
  rules {
    rule {
      include_mode     = "INCLUDE_ALL"
      severity_level   = "ERRORS"
      delay_in_minutes = 2
    }
  }
}

# Tier 3 WARNING — PERFORMANCE, 5 min delay — all envs
resource "dynatrace_alerting" "warning" {
  for_each        = var.teams
  name            = "${each.value}-${var.environment}-warning"
  management_zone = var.zone_ids[each.value]
  rules {
    rule {
      include_mode     = "INCLUDE_ALL"
      severity_level   = "PERFORMANCE"
      delay_in_minutes = 5
    }
  }
}

# Tier 4 INFO — RESOURCE_CONTENTION + CUSTOM_ALERT, 15 min delay — all envs
resource "dynatrace_alerting" "info" {
  for_each        = var.teams
  name            = "${each.value}-${var.environment}-info"
  management_zone = var.zone_ids[each.value]
  rules {
    rule {
      include_mode     = "INCLUDE_ALL"
      severity_level   = "RESOURCE_CONTENTION"
      delay_in_minutes = 15
    }
    rule {
      include_mode     = "INCLUDE_ALL"
      severity_level   = "CUSTOM_ALERT"
      delay_in_minutes = 15
    }
  }
}

output "critical_profile_ids" {
  value = { for k, p in dynatrace_alerting.critical : k => p.id }
}

output "high_profile_ids" {
  value = { for k, p in dynatrace_alerting.high : k => p.id }
}

output "warning_profile_ids" {
  value = { for k, p in dynatrace_alerting.warning : k => p.id }
}

output "info_profile_ids" {
  value = { for k, p in dynatrace_alerting.info : k => p.id }
}
