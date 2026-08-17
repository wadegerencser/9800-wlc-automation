# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================

output "wlc_host" {
  description = "Target WLC hostname / IP"
  value       = var.wlc_host
}

output "ssh_version_enforced" {
  description = "SSH version enforced on the controller"
  value       = "SSHv2"
}

output "aaa_authentication_list" {
  description = "AAA login authentication method list name"
  value       = "AAA-AUTHEN"
}

output "syslog_destination" {
  description = "Remote syslog server receiving controller logs"
  value       = var.syslog_server_ip
}

output "ntp_primary" {
  description = "Primary NTP server configured on the controller"
  value       = var.ntp_server_primary
}

output "snmp_user" {
  description = "SNMPv3 user provisioned on the controller"
  value       = var.snmp_user_name
}

output "stig_controls_applied" {
  description = "NIST SP 800-53 / STIG control families addressed by this module"
  value = [
    "AC-8  (Login Banner)       – STIG V-220142",
    "AC-11 (Exec Timeout)       – STIG V-220153",
    "AU-2  (Audit Events)       – STIG V-220146",
    "AU-8  (NTP)                – STIG V-220147",
    "CM-7  (Services Disabled)  – STIG V-220149, V-220155",
    "IA-2  (AAA Authentication) – STIG V-220143",
    "IA-5  (Enable Secret)      – STIG V-220141, V-220154",
    "SC-8  (SSH / SNMPv3)       – STIG V-220148, V-220151, V-220152",
  ]
}
