###############################################################################
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
###############################################################################
#
# Site Tag Automation – Cisco Catalyst 9800 WLC (Terraform / RESTCONF)
#
# Creates site tags from the var.site_tags list via the iosxe provider.
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

resource "iosxe_restconf" "site_tag" {
  for_each = { for tag in var.site_tags : tag.name => tag }

  path = "Cisco-IOS-XE-wireless-site-cfg:site-cfg-data/site-tag-configs/site-tag-config=${each.key}"

  attributes = merge(
    {
      "site-tag-name" = each.value.name
      "description"   = each.value.description
      "ap-profile"    = each.value.ap_profile
      "local-site"    = tostring(each.value.local_site)
    },
    each.value.flex_profile != "" ? { "flex-profile" = each.value.flex_profile } : {}
  )
}
