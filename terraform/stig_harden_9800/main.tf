###############################################################################
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
###############################################################################
#
# STIG Hardening – Cisco Catalyst 9800 WLC (Terraform / RESTCONF)
#
# Uses the CiscoDevNet/iosxe provider to push DISA STIG hardening via RESTCONF.
# Each resource block cites its STIG Vuln ID and NIST SP 800-53 control.
#
# Maps to: DISA IOS-XE Router NDM STIG → NIST SP 800-53 Rev 5
#
# ── Platform Quick-Start ──────────────────────────────────────────────────────
#
#   macOS (Homebrew)
#     brew tap hashicorp/tap && brew install hashicorp/tap/terraform
#     cp terraform.tfvars.example terraform.tfvars   # fill in real values
#     terraform init && terraform plan && terraform apply
#
#   Linux (apt)
#     wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor \
#       -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
#     echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
#       https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
#       | sudo tee /etc/apt/sources.list.d/hashicorp.list
#     sudo apt-get update && sudo apt-get install terraform
#     cp terraform.tfvars.example terraform.tfvars
#     terraform init && terraform plan && terraform apply
#
#   Windows (PowerShell – winget)
#     winget install --id Hashicorp.Terraform
#     copy terraform.tfvars.example terraform.tfvars
#     terraform init ; terraform plan ; terraform apply
#
#   All platforms — pass secrets via environment variables (avoids tfvars):
#     export TF_VAR_wlc_password="secret"
#     export TF_VAR_tacacs_shared_key="secret"
#     export TF_VAR_snmp_auth_password="secret"
#     export TF_VAR_snmp_priv_password="secret"
#     export TF_VAR_enable_secret="secret"
#     export TF_VAR_ntp_auth_key_value="secret"
#
#   Dry-run (plan only — no changes applied):
#     terraform plan
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

# ── SSH Hardening  (STIG: V-220151, V-220152 | NIST: SC-8, SC-10) ─────────
resource "iosxe_restconf" "ssh_hardening" {
  path = "Cisco-IOS-XE-native:native/ip/ssh"
  attributes = {
    "version"                = "2"
    "time-out"               = tostring(var.ssh_timeout)
    "authentication-retries" = tostring(var.ssh_auth_retries)
  }
}

resource "iosxe_restconf" "vty_transport" {
  path = "Cisco-IOS-XE-native:native/line/vty"
  attributes = {
    "first"           = "0"
    "last"            = "15"
    "transport/input" = "ssh"
    "exec-timeout/minutes" = tostring(var.exec_timeout_minutes)
    "exec-timeout/seconds" = "0"
  }

  depends_on = [iosxe_restconf.ssh_hardening]
}

# ── DoD Login Banner  (STIG: V-220142 | NIST: AC-8) ──────────────────────
resource "iosxe_restconf" "login_banner" {
  path = "Cisco-IOS-XE-native:native/banner/login"
  attributes = {
    "banner" = "You are accessing a U.S. Government Information System provided for USG-authorized use only. Unauthorized use is prohibited and subject to criminal and civil penalties."
  }
}

# ── AAA / TACACS+  (STIG: V-220143, V-220144, V-220145 | NIST: IA-2, AC-3, AU-12)
resource "iosxe_restconf" "tacacs_server" {
  path = "Cisco-IOS-XE-native:native/tacacs/server=TACACS-PRIMARY"
  attributes = {
    "name"              = "TACACS-PRIMARY"
    "address/ipv4"      = var.tacacs_server_ip
    "key/encryption"    = "0"
    "key/key"           = var.tacacs_shared_key
  }
}

resource "iosxe_restconf" "aaa_new_model" {
  path = "Cisco-IOS-XE-aaa:aaa/new-model"
  attributes = {}

  depends_on = [iosxe_restconf.tacacs_server]
}

resource "iosxe_restconf" "aaa_authentication" {
  path = "Cisco-IOS-XE-aaa:aaa/authentication/login=AAA-AUTHEN"
  attributes = {
    "name"       = "AAA-AUTHEN"
    "a1/group/name" = "tacacs+"
    "a2/local"   = ""
  }

  depends_on = [iosxe_restconf.aaa_new_model]
}

resource "iosxe_restconf" "aaa_authorization" {
  path = "Cisco-IOS-XE-aaa:aaa/authorization/exec=AAA-AUTHOR"
  attributes = {
    "name"          = "AAA-AUTHOR"
    "a1/group/name" = "tacacs+"
    "a2/local"      = ""
  }

  depends_on = [iosxe_restconf.aaa_new_model]
}

resource "iosxe_restconf" "aaa_accounting" {
  path = "Cisco-IOS-XE-aaa:aaa/accounting/exec=AAA-ACCT"
  attributes = {
    "name"                     = "AAA-ACCT"
    "start-stop/group/name"    = "tacacs+"
  }

  depends_on = [iosxe_restconf.aaa_new_model]
}

# ── Syslog  (STIG: V-220146 | NIST: AU-2, AU-9) ───────────────────────────
resource "iosxe_restconf" "syslog" {
  path = "Cisco-IOS-XE-native:native/logging"
  attributes = {
    "host/ipv4-host-list/ipv4-host"     = var.syslog_server_ip
    "source-interface/interface-name"   = var.syslog_source_interface
    "trap/severity"                     = "informational"
    "buffered/size"                     = "65536"
  }
}

# ── NTP  (STIG: V-220147 | NIST: AU-8) ────────────────────────────────────
resource "iosxe_restconf" "ntp" {
  path = "Cisco-IOS-XE-native:native/ntp"
  attributes = {
    "authenticate"                              = ""
    "authentication-key/number"                 = tostring(var.ntp_auth_key_id)
    "authentication-key/md5/encryption"         = "0"
    "authentication-key/md5/value"              = var.ntp_auth_key_value
    "trusted-key/key-number"                    = tostring(var.ntp_auth_key_id)
    "source/source-interface"                   = var.ntp_server_primary
    "server/server-list/ip-address"             = var.ntp_server_primary
  }
}

# ── SNMPv3  (STIG: V-220148 | NIST: SC-8, IA-2) ──────────────────────────
resource "iosxe_restconf" "snmp_v3_group" {
  path = "Cisco-IOS-XE-native:native/snmp-server/group=SNMP-V3-RO"
  attributes = {
    "id"       = "SNMP-V3-RO"
    "v3/priv"  = ""
  }
}

resource "iosxe_restconf" "snmp_v3_user" {
  path = "Cisco-IOS-XE-native:native/snmp-server/user=${var.snmp_user_name}"
  attributes = {
    "name"                  = var.snmp_user_name
    "grpname"               = "SNMP-V3-RO"
    "v3/auth/algorithm"     = var.snmp_auth_protocol
    "v3/auth/password"      = var.snmp_auth_password
    "v3/priv/algorithm"     = "aes"
    "v3/priv/password"      = var.snmp_priv_password
  }

  depends_on = [iosxe_restconf.snmp_v3_group]
}

resource "iosxe_restconf" "snmp_system" {
  path = "Cisco-IOS-XE-native:native/snmp-server"
  attributes = {
    "contact"  = var.snmp_contact
    "location" = var.snmp_location
  }
}

# ── Disable HTTP server  (STIG: V-220149 | NIST: CM-7) ───────────────────
resource "iosxe_restconf" "no_http_server" {
  path = "Cisco-IOS-XE-native:native/ip/http/server"
  attributes = {
    "server" = "false"
  }
}

# ── Disable IP source route  (STIG: V-220155 | NIST: CM-7) ──────────────
resource "iosxe_restconf" "no_ip_source_route" {
  path = "Cisco-IOS-XE-native:native/ip/source-route"
  attributes = {
    "source-route" = "false"
  }
}

# ── Enable password encryption  (STIG: V-220154 | NIST: IA-5) ────────────
resource "iosxe_restconf" "password_encryption" {
  path = "Cisco-IOS-XE-native:native/service/password-encryption"
  attributes = {}
}
