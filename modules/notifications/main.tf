# Notifications: wire alerting profiles to PagerDuty (critical/high) and Slack (warning/info).
# Empty PD keys in dev create no PagerDuty resources (by design).
# Profile IDs come from modules/alerting outputs.

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

variable "critical_profile_ids" {
  type    = map(string)
  default = {}
}

variable "high_profile_ids" {
  type    = map(string)
  default = {}
}

variable "warning_profile_ids" {
  type = map(string)
}

variable "info_profile_ids" {
  type = map(string)
}

## PagerDuty ← critical (prod profiles only exist when wired)
resource "dynatrace_pager_duty_notification" "critical" {
  for_each = {
    for team, key in var.pagerduty_integration_keys : team => key
    if contains(keys(var.critical_profile_ids), team)
  }
  name    = "${each.key}-${var.environment}-critical-pd"
  active  = true
  profile = var.critical_profile_ids[each.key]
  account = "${each.key}-oncall"
  service = each.key
  api_key = each.value
}

# PagerDuty ← high
resource "dynatrace_pager_duty_notification" "high" {
  for_each = {
    for team, key in var.pagerduty_integration_keys : team => key
    if contains(keys(var.high_profile_ids), team)
  }
  name    = "${each.key}-${var.environment}-high-pd"
  active  = true
  profile = var.high_profile_ids[each.key]
  account = "${each.key}-oncall"
  service = each.key
  api_key = each.value
}

# Slack ← warning
resource "dynatrace_slack_notification" "warning" {
  for_each = {
    for team, url in var.slack_webhook_urls : team => url
    if contains(keys(var.warning_profile_ids), team)
  }
  name    = "${each.key}-${var.environment}-warning-slack"
  active  = true
  profile = var.warning_profile_ids[each.key]
  url     = each.value
  channel = "#alerts-${each.key}"
  message = "[${upper(var.environment)}] {State} | {ProblemSeverity} | {ProblemTitle} | {ProblemURL}"
}

# Slack ← info
resource "dynatrace_slack_notification" "info" {
  for_each = {
    for team, url in var.slack_webhook_urls : team => url
    if contains(keys(var.info_profile_ids), team)
  }
  name    = "${each.key}-${var.environment}-info-slack"
  active  = true
  profile = var.info_profile_ids[each.key]
  url     = each.value
  channel = "#monitoring"
  message = "[INFO][${upper(var.environment)}] {State} | ${each.key} | {ProblemTitle} | {ProblemURL}"
}

output "pagerduty_critical_ids" {
  value = { for k, n in dynatrace_pager_duty_notification.critical : k => n.id }
}

output "slack_warning_ids" {
  value = { for k, n in dynatrace_slack_notification.warning : k => n.id }
}
