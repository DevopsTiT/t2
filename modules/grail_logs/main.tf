# Grail logs: route ERROR/Exception lines into a retention bucket + PARSE JSON fields.
# Optional one-shot dynatrace_log_grail activation stays off by default.
# Does not replace Notebooks or OneAgent log ingest setup.

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

variable "enable_grail_activation" {
  type    = bool
  default = false
}

variable "error_log_bucket_name" {
  type        = string
  default     = "default_logs"
  description = "Existing Grail log bucket name to route matched logs into (tenant-specific)."
}

# One-time Logs-on-Grail activation. Endpoint is deprecated for ongoing use.
# Keep disabled by default; set enable_grail_activation=true only if needed.
resource "dynatrace_log_grail" "activate" {
  count                 = var.enable_grail_activation ? 1 : 0
  activated             = true
  parallel_ingest_period = "NONE"
}

# Route error-like logs into a retention bucket (matcher is DQL-style phrase match).
resource "dynatrace_log_buckets" "app_errors" {
  enabled     = true
  bucket_name = var.error_log_bucket_name
  matcher     = "matchesPhrase(content, \"ERROR\") or matchesPhrase(content, \"Exception\")"
  rule_name   = "tf-${var.environment}-app-errors-to-bucket"
}

# Extract status/latency fields from JSON app logs for Grail analytics.
resource "dynatrace_log_processing" "json_http_fields" {
  enabled   = true
  query     = "matchesPhrase(content, \"\\\"status\\\"\")"
  rule_name = "tf-${var.environment}-parse-http-json"
  processor_definition {
    rule = <<-EOT
      PARSE(content, "JSON:json")
      | FIELDS_ADD(
          http.status: json[status],
          http.path: json[path],
          service.name: json[service]
        )
      | FIELDS_REMOVE(json)
    EOT
  }
  rule_testing {
    sample_log = jsonencode({
      content = "{\"status\":500,\"path\":\"/pay\",\"service\":\"payment-service\",\"message\":\"ERROR\"}"
    })
  }
}

output "log_bucket_rule_id" {
  value = dynatrace_log_buckets.app_errors.id
}

output "log_processing_rule_id" {
  value = dynatrace_log_processing.json_http_fields.id
}

output "grail_activation_id" {
  value = try(dynatrace_log_grail.activate[0].id, null)
}
