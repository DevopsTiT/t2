# SLO v2: availability + latency targets per service.
# Uses error-budget burn-rate visualization for reliability decisions.
# Targets come from environments/*/local.services (slo_target, latency_p99_ms).

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

variable "services" {
  type = map(object({
    team             = string
    slo_target       = number
    latency_p99_ms   = number
  }))
}

resource "dynatrace_slo_v2" "availability" {
  for_each           = var.services
  name               = "${each.key} Availability [${var.environment}]"
  custom_description = "Availability SLO: ${each.value.slo_target}%. Team: ${each.value.team}."
  enabled            = true
  target_success     = each.value.slo_target
  target_warning     = each.value.slo_target - 0.1
  evaluation_window  = "-1M"
  evaluation_type    = "AGGREGATE"
  filter             = "type(\"SERVICE\"),entityName(\"${each.key}\")"
  metric_expression  = <<-EOT
    100*(builtin:service.requestCount.server
      :filter(and(eq(service.name,"${each.key}"),eq(environment,"${var.environment}")))
      :splitBy():sum
      - builtin:service.errors.server.count
      :filter(and(eq(service.name,"${each.key}"),eq(environment,"${var.environment}")))
      :splitBy():sum)
    / builtin:service.requestCount.server
      :filter(and(eq(service.name,"${each.key}"),eq(environment,"${var.environment}")))
      :splitBy():sum
  EOT
  error_budget_burn_rate {
    burn_rate_visualization_enabled = true
    fast_burn_threshold             = 14.4
  }
}

resource "dynatrace_slo_v2" "latency" {
  for_each           = var.services
  name               = "${each.key} Latency P99 [${var.environment}]"
  custom_description = "Latency P99 SLO for ${each.key}. Team: ${each.value.team}."
  enabled            = true
  target_success     = each.value.slo_target - 0.5
  target_warning     = each.value.slo_target - 0.6
  evaluation_window  = "-1M"
  evaluation_type    = "AGGREGATE"
  filter             = "type(\"SERVICE\"),entityName(\"${each.key}\")"
  metric_expression  = <<-EOT
    100*(builtin:service.requestCount.server
      :filter(and(
        eq(service.name,"${each.key}"),
        eq(environment,"${var.environment}"),
        le(builtin:service.response.time,${each.value.latency_p99_ms * 1000})
      ))
      :splitBy():sum)
    / builtin:service.requestCount.server
      :filter(and(eq(service.name,"${each.key}"),eq(environment,"${var.environment}")))
      :splitBy():sum
  EOT
  error_budget_burn_rate {
    burn_rate_visualization_enabled = true
    fast_burn_threshold             = 14.4
  }
}

output "availability_slo_ids" {
  value = { for k, s in dynatrace_slo_v2.availability : k => s.id }
}

output "latency_slo_ids" {
  value = { for k, s in dynatrace_slo_v2.latency : k => s.id }
}
