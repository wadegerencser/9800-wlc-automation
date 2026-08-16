###############################################################################
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
###############################################################################
#
# WPA3 SSID Adoption – Cisco Catalyst 9800 WLC (Terraform / RESTCONF)
#
# Uses the CiscoDevNet/iosxe provider to push WPA3 WLAN config via RESTCONF.
# Works identically on macOS, Linux, and Windows — Terraform is a single
# cross-platform binary with no runtime dependencies.
#
# ── Platform Quick-Start ──────────────────────────────────────────────────────
#
#   macOS (Homebrew)
#     brew tap hashicorp/tap && brew install hashicorp/tap/terraform
#
#   Linux (apt)
#     wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor \
#       -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
#     echo "deb [signed-by=...] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
#       | sudo tee /etc/apt/sources.list.d/hashicorp.list
#     sudo apt-get update && sudo apt-get install terraform
#
#   Windows (PowerShell – winget)
#     winget install --id Hashicorp.Terraform
#
#   All platforms – apply:
#     cp terraform.tfvars.example terraform.tfvars   # fill in real values
#     terraform init
#     terraform plan
#     terraform apply
#
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    iosxe = {
      source  = "CiscoDevNet/iosxe"
      version = ">= 0.5"
    }
  }
}

provider "iosxe" {
  host     = "https://${var.wlc_host}"
  username = var.wlc_username
  password = var.wlc_password
}

# ── Locals: build mode-specific YANG attributes ───────────────────────────────

locals {
  # Common WLAN attributes shared across all modes
  wlan_base = {
    profile-name       = var.wlan_profile_name
    id                 = tostring(var.wlan_id)
    ssid               = var.ssid_name
    status             = "true"
    wlan-policy-vlan   = tostring(var.vlan_id)
  }

  # WPA3-Personal: SAE only, WPA2 disabled, PMF required
  wpa3_personal = merge(local.wlan_base, {
    "wpa-cfg/wpa-version"           = "wpa3-personal"
    "wpa-cfg/akm-cfg/sae-enabled"   = "true"
    "wpa-cfg/akm-cfg/psk-enabled"   = "false"
    "wpa-cfg/pmf-cfg/pmf-state"     = "required"
    "wpa-cfg/psk-cfg/psk-type"      = "ascii"
    "wpa-cfg/psk-cfg/psk-value"     = var.sae_passphrase
  })

  # WPA3-Enterprise: 802.1X, PMF required, no PSK
  wpa3_enterprise = merge(local.wlan_base, {
    "wpa-cfg/wpa-version"              = "wpa3-enterprise"
    "wpa-cfg/akm-cfg/dot1x-enabled"    = "true"
    "wpa-cfg/akm-cfg/psk-enabled"      = "false"
    "wpa-cfg/pmf-cfg/pmf-state"        = "required"
    "dot1x-cfg/auth-list"              = "dot1x-WPA3"
  })

  # WPA2/WPA3 Transition: SAE + PSK both active, PMF optional
  wpa3_transition = merge(local.wlan_base, {
    "wpa-cfg/wpa-version"           = "wpa2-wpa3-transition"
    "wpa-cfg/akm-cfg/sae-enabled"   = "true"
    "wpa-cfg/akm-cfg/psk-enabled"   = "true"
    "wpa-cfg/pmf-cfg/pmf-state"     = "optional"
    "wpa-cfg/psk-cfg/psk-type"      = "ascii"
    "wpa-cfg/psk-cfg/psk-value"     = var.sae_passphrase
  })

  wlan_attributes = (
    var.wpa3_mode == "enterprise" ? local.wpa3_enterprise :
    var.wpa3_mode == "transition" ? local.wpa3_transition :
    local.wpa3_personal
  )
}

# ── WLAN profile ──────────────────────────────────────────────────────────────

resource "iosxe_restconf" "wpa3_wlan" {
  path = "Cisco-IOS-XE-wireless-wlan-cfg:wireless-cfg-data/wlan-cfg-data/wlan-cfg-entries/wlan-cfg-entry=${var.wlan_profile_name}"
  attributes = local.wlan_attributes
}

# ── RADIUS server (enterprise + transition) ───────────────────────────────────

resource "iosxe_restconf" "radius_server" {
  count = var.wpa3_mode != "personal" ? 1 : 0
  path  = "Cisco-IOS-XE-aaa:aaa-data/radius/server/RADIUS-WPA3"
  attributes = {
    name                = "RADIUS-WPA3"
    address-ipv4        = var.radius_server_ip
    authentication-port = "1812"
    accounting-port     = "1813"
    shared-secret       = var.radius_shared_key
  }
}

# ── Policy profile ────────────────────────────────────────────────────────────

resource "iosxe_restconf" "policy_profile" {
  path = "Cisco-IOS-XE-wireless-wlan-cfg:wireless-cfg-data/policy-cfg-data/policy-profile-entries/policy-profile-entry=${var.policy_profile_name}"
  attributes = {
    profile-name = var.policy_profile_name
    vlan-name    = "VLAN${var.vlan_id}"
    status       = "true"
  }

  depends_on = [iosxe_restconf.wpa3_wlan]
}

# ── Policy tag ────────────────────────────────────────────────────────────────

resource "iosxe_restconf" "policy_tag" {
  path = "Cisco-IOS-XE-wireless-wlan-cfg:wireless-cfg-data/tag-cfg-data/policy-tag-entries/policy-tag-entry=${var.policy_tag_name}"
  attributes = {
    policy-tag-name = var.policy_tag_name
    wlan-profile    = var.wlan_profile_name
    policy-profile  = var.policy_profile_name
  }

  depends_on = [iosxe_restconf.policy_profile]
}
