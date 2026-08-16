# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================

output "wlan_profile_name" {
  description = "Deployed WLAN profile name"
  value       = var.wlan_profile_name
}

output "ssid_name" {
  description = "Deployed SSID"
  value       = var.ssid_name
}

output "wpa3_mode" {
  description = "WPA3 mode that was applied"
  value       = var.wpa3_mode
}

output "vlan_id" {
  description = "Client VLAN ID assigned to this WLAN"
  value       = var.vlan_id
}

output "policy_tag_name" {
  description = "Policy tag to assign to APs for this WLAN"
  value       = var.policy_tag_name
}
