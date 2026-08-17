# Metric events: static thresholds that open Dynatrace Problems.
# Covers traffic, errors, latency, CPU, memory, JVM heap, pod restarts, network.
# Thresholds come from environments/*/local.services — tune there first.

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
    team                   = string
    traffic_min_rps        = number
    error_rate_alert       = number
    latency_p99_ms         = number
    cpu_saturation_pct     = number
    memory_usage_pct       = number
    jvm_heap_pct           = number
    pod_restart_threshold  = number
    network_error_rate_pct = number
  }))
}

locals {
  services_with_traffic = {
    for name, svc in var.services : name => svc
    if svc.traffic_min_rps > 0
  }
}

# 1) Traffic drop
resource "dynatrace_metric_events" "traffic_drop" {
  for_each                   = local.services_with_traffic
  enabled                    = true
  event_entity_dimension_key = "dt.entity.service"
  summary                    = "[${upper(var.environment)}] ${each.key}: Traffic drop (<${each.value.traffic_min_rps} req/min)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: Traffic drop (<${each.value.traffic_min_rps} req/min)"
    description = "${each.key} traffic below ${each.value.traffic_min_rps} req/min for 3 consecutive minutes. Check ALB, DNS, recent deploys. Team: ${each.value.team}"
    event_type  = "ERROR"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "BELOW"
    alert_on_no_data   = true
    dealerting_samples = 5
    samples            = 5
    threshold          = each.value.traffic_min_rps
    violating_samples  = 3
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "SUM"
    metric_key  = "builtin:service.requestCount.server"
    dimension_filter {
      filter {
        dimension_key   = "service.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 2) Error rate
resource "dynatrace_metric_events" "error_rate" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.service"
  summary                    = "[${upper(var.environment)}] ${each.key}: High error rate (>${each.value.error_rate_alert}%)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: High error rate (>${each.value.error_rate_alert}%)"
    description = "${each.key} HTTP 5xx error rate exceeded ${each.value.error_rate_alert}%. Team: ${each.value.team}"
    event_type  = "ERROR"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 5
    threshold          = each.value.error_rate_alert
    violating_samples  = 3
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "AVG"
    metric_key  = "builtin:service.errors.server.rate"
    dimension_filter {
      filter {
        dimension_key   = "service.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 3) Latency P99 (DT stores response time in microseconds)
resource "dynatrace_metric_events" "latency_p99" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.service"
  summary                    = "[${upper(var.environment)}] ${each.key}: P99 latency >${each.value.latency_p99_ms}ms"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: P99 latency >${each.value.latency_p99_ms}ms"
    description = "${each.key} P99 response time exceeded ${each.value.latency_p99_ms}ms. Team: ${each.value.team}"
    event_type  = "SLOWDOWN"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 5
    threshold          = each.value.latency_p99_ms * 1000
    violating_samples  = 3
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "AVG"
    metric_key  = "builtin:service.response.time:percentile(99)"
    dimension_filter {
      filter {
        dimension_key   = "service.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 4) CPU
resource "dynatrace_metric_events" "cpu_saturation" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.process_group_instance"
  summary                    = "[${upper(var.environment)}] ${each.key}: CPU saturation (>${each.value.cpu_saturation_pct}%)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: CPU saturation (>${each.value.cpu_saturation_pct}%)"
    description = "${each.key} process CPU above ${each.value.cpu_saturation_pct}%. Team: ${each.value.team}"
    event_type  = "RESOURCE"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 5
    threshold          = each.value.cpu_saturation_pct
    violating_samples  = 5
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "AVG"
    metric_key  = "builtin:process.cpu.usage"
    dimension_filter {
      filter {
        dimension_key   = "process.group.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 5) Memory
resource "dynatrace_metric_events" "memory_usage" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.process_group_instance"
  summary                    = "[${upper(var.environment)}] ${each.key}: Memory usage (>${each.value.memory_usage_pct}%)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: Memory usage (>${each.value.memory_usage_pct}%)"
    description = "${each.key} RSS memory above ${each.value.memory_usage_pct}% of limit. OOM risk. Team: ${each.value.team}"
    event_type  = "RESOURCE"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 5
    threshold          = each.value.memory_usage_pct
    violating_samples  = 5
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "AVG"
    metric_key  = "builtin:process.memory.usage"
    dimension_filter {
      filter {
        dimension_key   = "process.group.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 6) JVM heap
resource "dynatrace_metric_events" "jvm_heap" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.process_group_instance"
  summary                    = "[${upper(var.environment)}] ${each.key}: JVM heap (>${each.value.jvm_heap_pct}% of Xmx)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: JVM heap (>${each.value.jvm_heap_pct}% of Xmx)"
    description = "${each.key} heap utilisation above ${each.value.jvm_heap_pct}%. Team: ${each.value.team}"
    event_type  = "RESOURCE"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 5
    threshold          = each.value.jvm_heap_pct
    violating_samples  = 5
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "AVG"
    metric_key  = "builtin:process.memory.jvm.heapUtilization"
    dimension_filter {
      filter {
        dimension_key   = "process.group.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 7) Pod restarts
resource "dynatrace_metric_events" "pod_restarts" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.cloud_application"
  summary                    = "[${upper(var.environment)}] ${each.key}: Pod restarting (>${each.value.pod_restart_threshold} in 5 min)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: Pod restarting (>${each.value.pod_restart_threshold} in 5 min)"
    description = "${each.key} had >${each.value.pod_restart_threshold} pod restarts in 5 min. Team: ${each.value.team}"
    event_type  = "ERROR"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 1
    threshold          = each.value.pod_restart_threshold
    violating_samples  = 1
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "SUM"
    metric_key  = "builtin:kubernetes.workload.pods.restarts"
    dimension_filter {
      filter {
        dimension_key   = "workload.name"
        dimension_value = each.key
        operator        = "EQUALS"
      }
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

# 8) Network error rate (good-to-have)
resource "dynatrace_metric_events" "network_error_rate" {
  for_each                   = var.services
  enabled                    = true
  event_entity_dimension_key = "dt.entity.host"
  summary                    = "[${upper(var.environment)}] ${each.key}: Network errors (>${each.value.network_error_rate_pct}%)"
  event_template {
    title       = "[${upper(var.environment)}] ${each.key}: Network errors (>${each.value.network_error_rate_pct}%)"
    description = "${each.key} host network packet error rate above ${each.value.network_error_rate_pct}%. Check node network, ALB, security groups. Team: ${each.value.team}"
    event_type  = "RESOURCE"
  }
  model_properties {
    type               = "STATIC_THRESHOLD"
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 3
    samples            = 5
    threshold          = each.value.network_error_rate_pct
    violating_samples  = 3
  }
  query_definition {
    type        = "METRIC_KEY"
    aggregation = "AVG"
    metric_key  = "builtin:host.net.errorRate"
    dimension_filter {
      filter {
        dimension_key   = "environment"
        dimension_value = var.environment
        operator        = "EQUALS"
      }
    }
  }
}

output "metric_event_ids" {
  value = {
    traffic_drop       = { for k, r in dynatrace_metric_events.traffic_drop : k => r.id }
    error_rate         = { for k, r in dynatrace_metric_events.error_rate : k => r.id }
    latency_p99        = { for k, r in dynatrace_metric_events.latency_p99 : k => r.id }
    cpu_saturation     = { for k, r in dynatrace_metric_events.cpu_saturation : k => r.id }
    memory_usage       = { for k, r in dynatrace_metric_events.memory_usage : k => r.id }
    jvm_heap           = { for k, r in dynatrace_metric_events.jvm_heap : k => r.id }
    pod_restarts       = { for k, r in dynatrace_metric_events.pod_restarts : k => r.id }
    network_error_rate = { for k, r in dynatrace_metric_events.network_error_rate : k => r.id }
  }
}
