##############################################################################
# Example locals — teams derived from services map (Core seq 38 pattern).
##############################################################################

locals {
  # Unique team names from the services map
  teams = toset([for svc in values(var.services) : svc.team])

  # Host-group naming convention (OneAgent sets this at install time — outside TF)
  # Example: payments-production, orders-staging
  host_group_pattern = "{team}-{environment}"

  # Common tags applied via auto-tag / synthetic tags
  managed_by = "terraform"
}
