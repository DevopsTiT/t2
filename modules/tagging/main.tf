# Tagging: autotag environment/team from host-group name + host naming rules.
# Host groups themselves are set at OneAgent install (outside Terraform).
# On shared tenants, apply this module from only one environment root.

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

## Auto-tag key "environment" from host-group name containing the env string.
# Host groups are assigned at OneAgent install (outside Terraform).
resource "dynatrace_autotag_v2" "environment" {
  name        = "environment"
  description = "Tag entities with environment=${var.environment} when host group name contains the env."
  rules {
    rule {
      type                = "ME"
      enabled             = true
      value_format        = var.environment
      value_normalization = "Leave text as-is"
      attribute_rule {
        entity_type           = "HOST"
        host_to_pgpropagation = true
        conditions {
          condition {
            key            = "HOST_GROUP_NAME"
            operator       = "CONTAINS"
            string_value   = var.environment
            case_sensitive = false
          }
        }
      }
    }
  }
}

# Single tag key "team" with one rule per team (value_format = team name).
resource "dynatrace_autotag_v2" "team" {
  name        = "team"
  description = "Tag hosts by team when host group name begins with the team slug."
  rules {
    dynamic "rule" {
      for_each = var.teams
      content {
        type                = "ME"
        enabled             = true
        value_format        = rule.value
        value_normalization = "Leave text as-is"
        attribute_rule {
          entity_type           = "HOST"
          host_to_pgpropagation = true
          conditions {
            condition {
              key            = "HOST_GROUP_NAME"
              operator       = "BEGINS_WITH"
              string_value   = rule.value
              case_sensitive = false
            }
          }
        }
      }
    }
  }
}

# Managed-by tag for services already labeled via synthetics / manual tags.
resource "dynatrace_autotag_v2" "managed_by" {
  name        = "managed-by"
  description = "Mark Terraform-managed synthetic / tagged services."
  rules {
    rule {
      type                = "SELECTOR"
      enabled             = true
      value_format        = "terraform"
      value_normalization = "Leave text as-is"
      entity_selector     = "type(HTTP_CHECK),tag(\"[CONTEXTLESS]managed-by:terraform\")"
    }
  }
}

# Conditional host naming: prefer HostGroup + detected name in the UI.
# Note: creating the host group itself requires OneAgent --set-host-group=...
resource "dynatrace_host_naming" "with_host_group" {
  name    = "tf-${var.environment}-include-host-group"
  enabled = true
  format  = "{HostGroup:Name}-{Host:DetectedName}"
}

output "environment_autotag_id" {
  value = dynatrace_autotag_v2.environment.id
}

output "team_autotag_id" {
  value = dynatrace_autotag_v2.team.id
}

output "host_naming_id" {
  value = dynatrace_host_naming.with_host_group.id
}
