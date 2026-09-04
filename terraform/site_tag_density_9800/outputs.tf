###############################################################################
# Outputs – Site Tag Density Templates
# Cisco Catalyst 9800 WLC — sac-mgerencs-9800-wlc-automation
###############################################################################

output "rf_profile_24ghz_names" {
  description = "Names of provisioned 2.4 GHz RF profiles"
  value       = [for p in iosxe_restconf.rf_profile_24ghz : p.attributes["rf-profile-name"]]
}

output "rf_profile_5ghz_names" {
  description = "Names of provisioned 5 GHz RF profiles"
  value       = [for p in iosxe_restconf.rf_profile_5ghz : p.attributes["rf-profile-name"]]
}

output "rf_profile_6ghz_names" {
  description = "Names of provisioned 6 GHz RF profiles"
  value       = [for p in iosxe_restconf.rf_profile_6ghz : p.attributes["rf-profile-name"]]
}

output "rf_tag_names" {
  description = "Names of provisioned RF tags"
  value       = [for t in iosxe_restconf.rf_tag : t.attributes["rf-tag-name"]]
}

output "density_site_tag_names" {
  description = "Names of provisioned density site tags (all switching modes)"
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
