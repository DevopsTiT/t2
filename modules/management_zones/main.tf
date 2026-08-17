# Management zones: one zone per team for this environment.
# Scopes SERVICE + PROCESS_GROUP + HOST by team/environment tags.
# On-call use: limit Problems and dashboards to the owning team.

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
  type        = set(string)
  description = "Team names that get a management zone each"
}

resource "dynatrace_management_zone_v2" "team" {
  for_each    = var.teams
  name        = "${each.value}-${var.environment}"
  description = "Zone for team '${each.value}' in ${var.environment}. Scopes SERVICE + PROCESS_GROUP + HOST by tags."

  # Schema (~> 1.55): rule.type = ME|DIMENSION|SELECTOR
  # attribute_conditions MaxItems = 1; nest multiple condition {} (AND)
  # condition fields: key / operator / tag
  rules {
    rule {
      type    = "ME"
      enabled = true
      attribute_rule {
        entity_type = "SERVICE"
        attribute_conditions {
          condition {
            key      = "SERVICE_TAGS"
            operator = "EQUALS"
            tag      = "[CONTEXTLESS]team:${each.value}"
          }
          condition {
            key      = "SERVICE_TAGS"
            operator = "EQUALS"
            tag      = "[CONTEXTLESS]environment:${var.environment}"
          }
        }
      }
    }
    rule {
      type    = "ME"
      enabled = true
      attribute_rule {
        entity_type = "PROCESS_GROUP"
        attribute_conditions {
          condition {
            key      = "PROCESS_GROUP_TAGS"
            operator = "EQUALS"
            tag      = "[CONTEXTLESS]team:${each.value}"
          }
          condition {
            key      = "PROCESS_GROUP_TAGS"
            operator = "EQUALS"
            tag      = "[CONTEXTLESS]environment:${var.environment}"
          }
        }
      }
    }
    rule {
      type    = "ME"
      enabled = true
      attribute_rule {
        entity_type = "HOST"
        attribute_conditions {
          condition {
            key      = "HOST_TAGS"
            operator = "EQUALS"
            tag      = "[CONTEXTLESS]team:${each.value}"
          }
          condition {
            key      = "HOST_TAGS"
            operator = "EQUALS"
            tag      = "[CONTEXTLESS]environment:${var.environment}"
          }
        }
      }
    }
  }
}

output "zone_ids" {
  value = { for k, z in dynatrace_management_zone_v2.team : k => z.id }
}

output "zone_names" {
  value = { for k, z in dynatrace_management_zone_v2.team : k => z.name }
}
