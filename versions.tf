##############################################################################
# Shared provider pin (reference). Apply roots are environments/* .
# Provider: dynatrace-oss/dynatrace ~> 1.55 (schema-validated for MZ / events)
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.55"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}
