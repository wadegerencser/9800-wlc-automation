###############################################################################
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
###############################################################################
#
# Site Tag Density Templates – Cisco Catalyst 9800 WLC (Terraform / RESTCONF)
#
# Creates three sets of density-aware resources via the CiscoDevNet iosxe
# Terraform provider:
#   1. Per-band RF profiles (2.4 / 5 / 6 GHz) × three density tiers
#   2. RF tags binding those profiles into low / typical / high RF policies
#   3. Site tags for each density tier (central-switch and FlexConnect)
#
# 6 GHz PSD notes (LPI, FCC Part 15 Subpart E):
#   Low Power Indoor max: 5 dBm/MHz PSD, 30 dBm EIRP.
#   Typical 80 MHz LPI budget: 5 + 10*log10(80) ≈ 24 dBm total EIRP.
#   Standard Power (AFC) not modeled here — update rf_6_max_tx_power_high
#   variables and add AFC license config if SP mode is needed.
#
# ── Platform Quick-Start ──────────────────────────────────────────────────────
#
#   macOS
#     brew tap hashicorp/tap && brew install hashicorp/tap/terraform
#     cp terraform.tfvars.example terraform.tfvars
#     terraform init && terraform plan && terraform apply
#
#   Linux
#     sudo apt-get install -y gnupg software-properties-common
#     curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
#     echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
#       | sudo tee /etc/apt/sources.list.d/hashicorp.list
#     sudo apt-get update && sudo apt-get install terraform
#
#   Windows
#     winget install --id Hashicorp.Terraform
#     copy terraform.tfvars.example terraform.tfvars
#     terraform init && terraform plan && terraform apply
#
#   Android / iOS / NPC / tablet
#     Terraform has no native mobile app. Options:
#       1. SSH to a Linux/macOS jump host, run Terraform there.
#       2. Use HashiCorp Terraform Cloud — run from any browser or mobile.
#          terraform login   # link to Terraform Cloud
#          terraform init && terraform apply
#
#   Secrets via env vars (avoids storing password in tfvars):
#     export TF_VAR_wlc_password="your-password"
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

###############################################################################
# 2.4 GHz RF Profiles — one per density tier
###############################################################################

resource "iosxe_restconf" "rf_profile_24ghz" {
  for_each = { for p in var.rf_profiles_24ghz : p.name => p }

  path = "Cisco-IOS-XE-wireless-rf-cfg:rf-cfg-data/rf-profiles/rf-profile=${each.key}"

  attributes = {
    "rf-profile-name" = each.value.name
    "description"     = each.value.description
    "band"            = "dot11-2-dot-4-ghz-band"
    "tx-power-min"    = tostring(each.value.min_tx_power)
    "tx-power-max"    = tostring(each.value.max_tx_power)
    "tpc-ver1-thresh" = tostring(each.value.tpc_threshold)
    "rx-sop-threshold" = each.value.rx_sop_threshold
    "max-client-limit" = tostring(each.value.max_clients_per_radio)
  }
}

###############################################################################
# 5 GHz RF Profiles — one per density tier
###############################################################################

resource "iosxe_restconf" "rf_profile_5ghz" {
  for_each = { for p in var.rf_profiles_5ghz : p.name => p }

  path = "Cisco-IOS-XE-wireless-rf-cfg:rf-cfg-data/rf-profiles/rf-profile=${each.key}"

  attributes = {
    "rf-profile-name"  = each.value.name
    "description"      = each.value.description
    "band"             = "dot11-5-ghz-band"
    "tx-power-min"     = tostring(each.value.min_tx_power)
    "tx-power-max"     = tostring(each.value.max_tx_power)
    "tpc-ver1-thresh"  = tostring(each.value.tpc_threshold)
    "rx-sop-threshold" = each.value.rx_sop_threshold
    "max-client-limit" = tostring(each.value.max_clients_per_radio)
    "chan-width"        = each.value.channel_width
  }
}

###############################################################################
# 6 GHz RF Profiles — one per density tier
# Wi-Fi 6E (802.11ax) / Wi-Fi 7 (802.11be) only — no legacy CCK/DSSS clients.
# BSS Coloring, TWT, OFDMA, and MU-MIMO configured per tier.
###############################################################################

resource "iosxe_restconf" "rf_profile_6ghz" {
  for_each = { for p in var.rf_profiles_6ghz : p.name => p }

  path = "Cisco-IOS-XE-wireless-rf-cfg:rf-cfg-data/rf-profiles/rf-profile=${each.key}"

  attributes = {
    "rf-profile-name"         = each.value.name
    "description"             = each.value.description
    "band"                    = "dot11-6-ghz-band"
    "tx-power-min"            = tostring(each.value.min_tx_power)
    "tx-power-max"            = tostring(each.value.max_tx_power)
    "tpc-ver1-thresh"         = tostring(each.value.tpc_threshold)
    "rx-sop-threshold"        = each.value.rx_sop_threshold
    "max-client-limit"        = tostring(each.value.max_clients_per_radio)
    "chan-width"               = each.value.channel_width
    "dot11ax-bss-color-enable" = tostring(each.value.bss_color_enable)
    "dot11ax-twt-broadcast"   = tostring(each.value.twt_broadcast)
    "dot11ax-ofdma-dl"        = tostring(each.value.ofdma_downlink)
    "dot11ax-ofdma-ul"        = tostring(each.value.ofdma_uplink)
    "dot11ax-mu-mimo-dl"      = tostring(each.value.mu_mimo_downlink)
    "dot11ax-mu-mimo-ul"      = tostring(each.value.mu_mimo_uplink)
  }
}

###############################################################################
# RF Tags — bind 2.4/5/6 GHz profiles into a per-density RF policy
###############################################################################

resource "iosxe_restconf" "rf_tag" {
  for_each = { for t in var.rf_tags : t.name => t }

  path = "Cisco-IOS-XE-wireless-site-cfg:site-cfg-data/rf-tag-configs/rf-tag-config=${each.key}"

  attributes = {
    "rf-tag-name"      = each.value.name
    "description"      = each.value.description
    "dot11-24ghz-policy" = each.value.rf_profile_24ghz
    "dot11-5ghz-policy"  = each.value.rf_profile_5ghz
    "dot11-6ghz-policy"  = each.value.rf_profile_6ghz
  }

  depends_on = [
    iosxe_restconf.rf_profile_24ghz,
    iosxe_restconf.rf_profile_5ghz,
    iosxe_restconf.rf_profile_6ghz,
  ]
}

###############################################################################
# Site Tags — central switching density templates
###############################################################################

resource "iosxe_restconf" "density_site_tag" {
  for_each = {
    for tag in var.density_site_tags : tag.name => tag
    if !tag.local_site
  }

  path = "Cisco-IOS-XE-wireless-site-cfg:site-cfg-data/site-tag-configs/site-tag-config=${each.key}"

  attributes = merge(
    {
      "site-tag-name" = each.value.name
      "description"   = each.value.description
      "ap-profile"    = each.value.ap_profile
      "local-site"    = "false"
    }
  )
}

###############################################################################
# Site Tags — FlexConnect (local switching) density templates
###############################################################################

resource "iosxe_restconf" "density_site_tag_flex" {
  for_each = {
    for tag in var.density_site_tags : tag.name => tag
    if tag.local_site && tag.flex_profile == ""
  }

  path = "Cisco-IOS-XE-wireless-site-cfg:site-cfg-data/site-tag-configs/site-tag-config=${each.key}"

  attributes = {
    "site-tag-name" = each.value.name
    "description"   = each.value.description
    "ap-profile"    = each.value.ap_profile
    "local-site"    = "true"
  }
}

resource "iosxe_restconf" "density_site_tag_flex_profile" {
  for_each = {
    for tag in var.density_site_tags : tag.name => tag
    if tag.local_site && tag.flex_profile != ""
  }

  path = "Cisco-IOS-XE-wireless-site-cfg:site-cfg-data/site-tag-configs/site-tag-config=${each.key}"

  attributes = {
    "site-tag-name" = each.value.name
    "description"   = each.value.description
    "ap-profile"    = each.value.ap_profile
    "local-site"    = "true"
    "flex-profile"  = each.value.flex_profile
  }
}
