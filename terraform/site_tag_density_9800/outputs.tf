# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# =============================================================================

output "rf_profile_24ghz_names" {
  description = "2.4 GHz RF profile names provisioned on the WLC"
  value       = [for p in iosxe_restconf.rf_profile_24ghz : p.attributes["rf-profile-name"]]
}
output "rf_profile_5ghz_names" {
  description = "5 GHz RF profile names provisioned on the WLC"
  value       = [for p in iosxe_restconf.rf_profile_5ghz : p.attributes["rf-profile-name"]]
}
output "rf_profile_6ghz_names" {
  description = "6 GHz RF profile names provisioned on the WLC"
  value       = [for p in iosxe_restconf.rf_profile_6ghz : p.attributes["rf-profile-name"]]
}
output "rf_tag_names" {
  description = "RF tag names provisioned on the WLC"
  value       = [for t in iosxe_restconf.rf_tag : t.attributes["rf-tag-name"]]
}
output "density_site_tag_names" {
  description = "Site tag names provisioned (all switching modes)"
  value = concat(
    [for t in iosxe_restconf.density_site_tag : t.attributes["site-tag-name"]],
    [for t in iosxe_restconf.density_site_tag_flex : t.attributes["site-tag-name"]],
    [for t in iosxe_restconf.density_site_tag_flex_profile : t.attributes["site-tag-name"]],
  )
}
output "rf_tag_ap_assignment_commands" {
  description = "CLI commands to assign RF tags to APs — substitute <mac-address>"
  value = [for tag in var.density_site_tags :
    "ap <mac-address> tag rf ${tag.recommended_rf_tag}  # ${tag.name} [${tag.density_tier}]"
  ]
}
