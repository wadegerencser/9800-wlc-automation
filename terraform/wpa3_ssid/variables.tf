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

variable "wpa3_mode" {
  description = "WPA3 deployment mode: personal | enterprise | transition"
  type        = string
  default     = "personal"

  validation {
    condition     = contains(["personal", "enterprise", "transition"], var.wpa3_mode)
    error_message = "wpa3_mode must be 'personal', 'enterprise', or 'transition'."
  }
}

variable "wlan_id" {
  description = "WLAN ID (1–512, unique per WLC)"
  type        = number
  default     = 1
}

variable "ssid_name" {
  description = "SSID broadcast name"
  type        = string
  default     = "CORP-WPA3"
}

variable "wlan_profile_name" {
  description = "WLAN profile name — no spaces"
  type        = string
  default     = "wpa3-adoption"
}

variable "vlan_id" {
  description = "Client VLAN ID"
  type        = number
  default     = 100
}

variable "sae_passphrase" {
  description = "SAE/PSK passphrase for personal and transition modes (min 8 chars)"
  type        = string
  sensitive   = true
  default     = "ChangeMe-Str0ng!"
}

variable "radius_server_ip" {
  description = "RADIUS server IP address (enterprise and transition modes)"
  type        = string
  default     = "10.0.0.50"
}

variable "radius_shared_key" {
  description = "RADIUS shared secret — use TF_VAR_radius_shared_key or a secrets backend"
  type        = string
  sensitive   = true
  default     = "RadiusShared"
}

variable "policy_profile_name" {
  description = "Wireless policy profile name"
  type        = string
  default     = "wpa3-policy"
}

variable "policy_tag_name" {
  description = "Wireless policy tag name"
  type        = string
  default     = "wpa3-tag"
}
