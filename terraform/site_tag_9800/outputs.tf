# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# =============================================================================

output "site_tags_created" {
  description = "Site tag names provisioned on the WLC"
  value       = [for tag in var.site_tags : tag.name]
}
output "wlc_host" { value = var.wlc_host }
