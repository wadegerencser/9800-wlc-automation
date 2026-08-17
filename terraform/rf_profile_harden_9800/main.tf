###############################################################################
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
###############################################################################
#
# RF Profile Hardening – Cisco Catalyst 9800 WLC (Terraform / RESTCONF)
#
# Pushes 2.4 GHz and 5 GHz RF profiles via CiscoDevNet/iosxe provider.
#
# ── Platform Quick-Start ──────────────────────────────────────────────────────
#
#   macOS (Homebrew)
#     brew tap hashicorp/tap && brew install hashicorp/tap/terraform
#     cp terraform.tfvars.example terraform.tfvars
#     terraform init && terraform plan && terraform apply
#
#   Linux (apt)
#     sudo apt-get install -y terraform
#     cp terraform.tfvars.example terraform.tfvars
#     terraform init && terraform plan && terraform apply
#
#   Windows (PowerShell)
#     winget install --id Hashicorp.Terraform
#     copy terraform.tfvars.example terraform.tfvars
#     terraform init ; terraform plan ; terraform apply
#
#   Pass secrets via env (recommended):
#     export TF_VAR_wlc_password="secret"
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

resource "iosxe_restconf" "rf_profile_24ghz" {
  path = "Cisco-IOS-XE-wireless-rf-cfg:rf-cfg-data/rf-profiles/rf-profile=${var.rf_profile_24ghz_name}"
  attributes = {
    "profile-name"           = var.rf_profile_24ghz_name
    "band"                   = "24ghz"
    "description"            = var.rf_profile_24ghz_description
    "tx-power-min"           = tostring(var.rf_24_min_tx_power)
    "tx-power-max"           = tostring(var.rf_24_max_tx_power)
    "max-clients-per-radio"  = tostring(var.rf_24_max_clients_per_radio)
    "rx-sop-threshold"       = var.rf_24_rx_sop_threshold
    "status"                 = "true"
  }
}

resource "iosxe_restconf" "rf_profile_5ghz" {
  path = "Cisco-IOS-XE-wireless-rf-cfg:rf-cfg-data/rf-profiles/rf-profile=${var.rf_profile_5ghz_name}"
  attributes = {
    "profile-name"           = var.rf_profile_5ghz_name
    "band"                   = "5ghz"
    "description"            = var.rf_profile_5ghz_description
    "tx-power-min"           = tostring(var.rf_5_min_tx_power)
    "tx-power-max"           = tostring(var.rf_5_max_tx_power)
    "max-clients-per-radio"  = tostring(var.rf_5_max_clients_per_radio)
    "rx-sop-threshold"       = var.rf_5_rx_sop_threshold
    "chan-width"              = var.rf_5_channel_width
    "status"                 = "true"
  }
}
