# Synthetics: HTTP health monitors from Dynatrace geo locations.
# Outside-in check for actuator/health (2xx + "status":"UP").
# Complements in-cluster metric events when the edge path fails.

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

variable "synthetic_locations" {
  type = list(string)
}

variable "services" {
  type = map(object({
    team             = string
    health_check_url = string
    latency_p99_ms   = number
  }))
}

resource "dynatrace_http_monitor" "health_check" {
  for_each  = var.services
  name      = "${each.key} Health Check [${var.environment}]"
  enabled   = true
  frequency = 5
  locations = var.synthetic_locations

  script {
    request {
      description     = "Health check GET ${each.value.health_check_url}"
      method          = "GET"
      url             = each.value.health_check_url
      request_timeout = each.value.latency_p99_ms * 3
      configuration {
        accept_any_certificate = false
        follow_redirects       = true
      }
      validation {
        rule {
          type          = "httpStatusesList"
          value         = "2xx"
          pass_if_found = true
        }
        rule {
          type          = "patternConstraint"
          value         = "\"status\":\"UP\""
          pass_if_found = true
        }
      }
    }
  }

  anomaly_detection {
    outage_handling {
      global_outage = true
      global_outage_policy {
        consecutive_runs = 1
      }
      local_outage = true
      local_outage_policy {
        affected_locations = 1
        consecutive_runs   = 3
      }
    }
    loading_time_thresholds {
      enabled = true
      thresholds {
        threshold {
          type     = "TOTAL"
          value_ms = each.value.latency_p99_ms * 2
        }
      }
    }
  }

  tags {
    tag {
      context = "CONTEXTLESS"
      key     = "team"
      value   = each.value.team
    }
    tag {
      context = "CONTEXTLESS"
      key     = "environment"
      value   = var.environment
    }
    tag {
      context = "CONTEXTLESS"
      key     = "service"
      value   = each.key
    }
    tag {
      context = "CONTEXTLESS"
      key     = "managed-by"
      value   = "terraform"
    }
  }
}

output "monitor_ids" {
  value = { for k, m in dynatrace_http_monitor.health_check : k => m.id }
}
