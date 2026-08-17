###############################################################################
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
###############################################################################
#
# AP Join Profile – Cisco Catalyst 9800 WLC (Terraform / RESTCONF)
#
# ── Platform Quick-Start ──────────────────────────────────────────────────────
#
#   macOS   brew tap hashicorp/tap && brew install hashicorp/tap/terraform
#   Linux   sudo apt-get install terraform
#   Windows winget install --id Hashicorp.Terraform
#
#   All:    cp terraform.tfvars.example terraform.tfvars
#           terraform init && terraform plan && terraform apply
#
#   Secrets via env: export TF_VAR_wlc_password="secret"
#
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    iosxe = { source = "CiscoDevNet/iosxe"; version = ">= 0.5" }
  }
}

provider "iosxe" {
  host     = "https://${var.wlc_host}"
  username = var.wlc_username
  password = var.wlc_password
}

resource "iosxe_restconf" "ap_join_profile" {
  path = "Cisco-IOS-XE-wireless-ap-cfg:ap-cfg-data/ap-profiles/ap-profile=${var.ap_join_profile_name}"
  attributes = {
    "profile-name"                          = var.ap_join_profile_name
    "description"                           = var.ap_join_profile_description
    "ap-system-logging/syslog-host"         = var.ap_syslog_host
    "ap-system-logging/syslog-level"        = var.ap_syslog_level
    "ntp-server"                            = var.ap_ntp_server
    "capwap-timers/echo-interval"           = tostring(var.ap_capwap_echo_interval)
    "capwap-timers/fast-heartbeat-timeout"  = "true"
    "tcp-mss-adjust"                        = tostring(var.ap_tcp_mss_value)
    "led-state"                             = tostring(var.ap_led_state)
    "telnet"                                = "false"
    "ssh"                                   = "true"
  }
}
