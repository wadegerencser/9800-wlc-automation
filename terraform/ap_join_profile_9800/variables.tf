# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================

variable "wlc_host"     { type = string; description = "9800 WLC IP or hostname" }
variable "wlc_username" { type = string; description = "WLC management username" }
variable "wlc_password" { type = string; sensitive = true; description = "Use TF_VAR_wlc_password" }

variable "ap_join_profile_name"        { type = string; default = "AP-Join-Standard" }
variable "ap_join_profile_description" { type = string; default = "Standard AP join profile — NaC managed" }
variable "ap_syslog_host"              { type = string; default = "10.0.0.20" }
variable "ap_syslog_level"             { type = string; default = "warnings" }
variable "ap_ntp_server"               { type = string; default = "10.0.0.30" }
variable "ap_capwap_echo_interval"     { type = number; default = 30 }
variable "ap_tcp_mss_value"            { type = number; default = 1250 }
variable "ap_led_state"                { type = bool;   default = true }
