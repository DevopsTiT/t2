# Dashboards: one shared JSON SRE overview per environment.
# Tiles: failure rate, request count, host network errors, RCA markdown.
# Uses dynatrace_json_dashboard (needs ReadConfig/WriteConfig token scopes).

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

variable "owner" {
  type    = string
  default = "terraform-sre"
}

variable "service_names" {
  type        = list(string)
  description = "Service names shown in dashboard title/tags"
}

# Classic JSON dashboard API via dynatrace_json_dashboard (not dashboard_v2).
# Requires ReadConfig + WriteConfig token scopes.
resource "dynatrace_json_dashboard" "sre_overview" {
  contents = jsonencode({
    dashboardMetadata = {
      name                = "SRE Overview [${var.environment}]"
      shared              = true
      owner               = var.owner
      tags                = concat(["terraform", "sre", var.environment], var.service_names)
      preset              = false
      hasConsistentColors = false
    }
    tiles = [
      {
        name                  = "Header"
        tileType              = "HEADER"
        configured            = true
        bounds                = { top = 0, left = 0, width = 1140, height = 38 }
        tileFilter            = {}
        isAutoRefreshDisabled = false
      },
      {
        name                  = "Failure rate by service"
        tileType              = "DATA_EXPLORER"
        configured            = true
        bounds                = { top = 38, left = 0, width = 570, height = 304 }
        tileFilter            = {}
        isAutoRefreshDisabled = false
        customName            = "Failure rate by service"
        queries = [
          {
            id               = "A"
            metric           = "builtin:service.errors.server.rate"
            spaceAggregation = "AVG"
            timeAggregation  = "DEFAULT"
            splitBy          = ["dt.entity.service"]
            sortBy           = "DESC"
            sortByDimension  = ""
            filterBy         = { nestedFilters = [], criteria = [] }
            limit            = 20
            rate             = "NONE"
            enabled          = true
          }
        ]
        visualConfig = {
          type   = "TOP_LIST"
          global = { hideLegend = false }
          rules  = [{ matcher = "A:", properties = { color = "DEFAULT" }, seriesOverrides = [] }]
          axes   = { xAxis = { visible = true }, yAxes = [] }
        }
        queriesSettings   = { resolution = "" }
        metricExpressions = [
          "resolution=Inf&(builtin:service.errors.server.rate:splitBy(\"dt.entity.service\"):sort(value(auto,descending)):limit(20)):limit(100):names"
        ]
      },
      {
        name                  = "Request count"
        tileType              = "DATA_EXPLORER"
        configured            = true
        bounds                = { top = 38, left = 570, width = 570, height = 304 }
        tileFilter            = {}
        isAutoRefreshDisabled = false
        customName            = "Request count by service"
        queries = [
          {
            id               = "A"
            metric           = "builtin:service.requestCount.server"
            spaceAggregation = "SUM"
            timeAggregation  = "DEFAULT"
            splitBy          = ["dt.entity.service"]
            sortBy           = "DESC"
            sortByDimension  = ""
            filterBy         = { nestedFilters = [], criteria = [] }
            limit            = 20
            rate             = "NONE"
            enabled          = true
          }
        ]
        visualConfig = {
          type   = "GRAPH_CHART"
          global = { hideLegend = false }
          rules  = [{ matcher = "A:", properties = { color = "DEFAULT" }, seriesOverrides = [] }]
          axes = {
            xAxis = { visible = true }
            yAxes = [{
              displayName = ""
              visible     = true
              min         = "AUTO"
              max         = "AUTO"
              position    = "LEFT"
              queryIds    = ["A"]
              defaultAxis = true
            }]
          }
        }
        queriesSettings   = { resolution = "" }
        metricExpressions = [
          "resolution=null&(builtin:service.requestCount.server:splitBy(\"dt.entity.service\"):sum:sort(value(sum,descending)):limit(20)):limit(100):names"
        ]
      },
      {
        name                  = "Host network error rate"
        tileType              = "DATA_EXPLORER"
        configured            = true
        bounds                = { top = 342, left = 0, width = 570, height = 304 }
        tileFilter            = {}
        isAutoRefreshDisabled = false
        customName            = "Host network error rate"
        queries = [
          {
            id               = "A"
            metric           = "builtin:host.net.errorRate"
            spaceAggregation = "AVG"
            timeAggregation  = "DEFAULT"
            splitBy          = ["dt.entity.host"]
            sortBy           = "DESC"
            sortByDimension  = ""
            filterBy         = { nestedFilters = [], criteria = [] }
            limit            = 20
            rate             = "NONE"
            enabled          = true
          }
        ]
        visualConfig = {
          type   = "TOP_LIST"
          global = { hideLegend = false }
          rules  = [{ matcher = "A:", properties = { color = "DEFAULT" }, seriesOverrides = [] }]
          axes   = { xAxis = { visible = true }, yAxes = [] }
        }
        queriesSettings   = { resolution = "" }
        metricExpressions = [
          "resolution=Inf&(builtin:host.net.errorRate:splitBy(\"dt.entity.host\"):sort(value(auto,descending)):limit(20)):limit(100):names"
        ]
      },
      {
        name                  = "Markdown RCA tips"
        tileType              = "MARKDOWN"
        configured            = true
        bounds                = { top = 342, left = 570, width = 570, height = 304 }
        tileFilter            = {}
        isAutoRefreshDisabled = false
        markdown              = "## RCA quick path\n1. Open Problem → Impacted services\n2. Check traffic drop + error rate tiles\n3. Jump to PurePath / logs in Grail\n4. Confirm synthetic health for ${var.environment}\n\nManaged by Terraform."
      }
    ]
  })
}

output "dashboard_id" {
  value = dynatrace_json_dashboard.sre_overview.id
}
