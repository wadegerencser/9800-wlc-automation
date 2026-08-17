# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================

variable "wlc_host" {
  description = "Cisco 9800 WLC IP or hostname (RESTCONF endpoint)"
  type        = string
}

variable "wlc_username" {
  description = "WLC management username"
  type        = string
}

variable "wlc_password" {
  description = "WLC management password — use TF_VAR_wlc_password or a secrets backend"
  type        = string
  sensitive   = true
}

# ── SSH  (NIST: SC-8 | STIG: V-220151, V-220152) ────────────────────────────
variable "ssh_timeout" {
  description = "SSH idle session timeout in seconds"
  type        = number
  default     = 60
}

variable "ssh_auth_retries" {
  description = "Maximum SSH authentication retry attempts"
  type        = number
  default     = 3
}

variable "exec_timeout_minutes" {
  description = "VTY/console exec idle timeout (minutes)"
  type        = number
  default     = 10
}

# ── AAA / TACACS+  (NIST: IA-2, AC-3, AU-12 | STIG: V-220143–V-220145) ─────
variable "tacacs_server_ip" {
  description = "TACACS+ server IP address"
  type        = string
  default     = "10.0.0.10"
}

variable "tacacs_server_port" {
  description = "TACACS+ server port"
  type        = number
  default     = 49
}

variable "tacacs_shared_key" {
  description = "TACACS+ shared secret — use TF_VAR_tacacs_shared_key or a secrets backend"
  type        = string
  sensitive   = true
}

# ── Syslog  (NIST: AU-2, AU-9 | STIG: V-220146) ─────────────────────────────
variable "syslog_server_ip" {
  description = "Remote syslog server IP"
  type        = string
  default     = "10.0.0.20"
}

variable "syslog_source_interface" {
  description = "Source interface for syslog packets"
  type        = string
  default     = "Loopback0"
}

# ── NTP  (NIST: AU-8 | STIG: V-220147) ──────────────────────────────────────
variable "ntp_server_primary" {
  description = "Primary NTP server IP"
  type        = string
  default     = "10.0.0.30"
}

variable "ntp_server_secondary" {
  description = "Secondary NTP server IP"
  type        = string
  default     = "10.0.0.31"
}

variable "ntp_auth_key_id" {
  description = "NTP authentication key ID"
  type        = number
  default     = 1
}

variable "ntp_auth_key_value" {
  description = "NTP authentication key value — use TF_VAR_ntp_auth_key_value"
  type        = string
  sensitive   = true
}

# ── SNMPv3  (NIST: SC-8, IA-2 | STIG: V-220148) ─────────────────────────────
variable "snmp_user_name" {
  description = "SNMPv3 user name"
  type        = string
  default     = "snmpv3user"
}

variable "snmp_auth_protocol" {
  description = "SNMPv3 auth protocol: sha | sha256 (never md5)"
  type        = string
  default     = "sha"

  validation {
    condition     = contains(["sha", "sha256"], var.snmp_auth_protocol)
    error_message = "snmp_auth_protocol must be 'sha' or 'sha256'."
  }
}

variable "snmp_auth_password" {
  description = "SNMPv3 auth password — use TF_VAR_snmp_auth_password"
  type        = string
  sensitive   = true
}

variable "snmp_priv_password" {
  description = "SNMPv3 priv (AES-128) password — use TF_VAR_snmp_priv_password"
  type        = string
  sensitive   = true
}

variable "snmp_contact" {
  description = "SNMP system contact string"
  type        = string
  default     = "noc@example.gov"
}

variable "snmp_location" {
  description = "SNMP system location string"
  type        = string
  default     = "DC1-RACK-A1"
}

# ── Enable Secret  (NIST: IA-5 | STIG: V-220141, V-220154) ──────────────────
variable "enable_secret" {
  description = "Enable secret password — use TF_VAR_enable_secret"
  type        = string
  sensitive   = true
}
