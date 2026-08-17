# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================

variable "wlc_host"     { type = string; description = "9800 WLC IP or hostname" }
variable "wlc_username" { type = string; description = "WLC management username" }
variable "wlc_password" { type = string; sensitive = true; description = "WLC management password — use TF_VAR_wlc_password" }

variable "rf_profile_24ghz_name"        { type = string; default = "RF-2.4GHz-Standard" }
variable "rf_profile_24ghz_description" { type = string; default = "2.4 GHz RF profile — NaC managed" }
variable "rf_24_min_tx_power"           { type = number; default = 7 }
variable "rf_24_max_tx_power"           { type = number; default = 17 }
variable "rf_24_max_clients_per_radio"  { type = number; default = 200 }
variable "rf_24_rx_sop_threshold"       { type = string; default = "medium"
  validation { condition = contains(["low","medium","high","auto"], var.rf_24_rx_sop_threshold)
               error_message = "rx_sop_threshold must be low, medium, high, or auto." } }
variable "rf_24_coverage_min_rssi"      { type = number; default = -80 }
variable "rf_24_coverage_exception"     { type = number; default = 25 }
variable "rf_24_dca_interval"           { type = number; default = 600 }

variable "rf_profile_5ghz_name"         { type = string; default = "RF-5GHz-Standard" }
variable "rf_profile_5ghz_description"  { type = string; default = "5 GHz RF profile — NaC managed" }
variable "rf_5_min_tx_power"            { type = number; default = 8 }
variable "rf_5_max_tx_power"            { type = number; default = 17 }
variable "rf_5_max_clients_per_radio"   { type = number; default = 200 }
variable "rf_5_rx_sop_threshold"        { type = string; default = "medium"
  validation { condition = contains(["low","medium","high","auto"], var.rf_5_rx_sop_threshold)
               error_message = "rx_sop_threshold must be low, medium, high, or auto." } }
variable "rf_5_channel_width"           { type = string; default = "best"
  validation { condition = contains(["20","40","80","best"], var.rf_5_channel_width)
               error_message = "channel_width must be 20, 40, 80, or best." } }
variable "rf_5_coverage_min_rssi"       { type = number; default = -80 }
variable "rf_5_coverage_exception"      { type = number; default = 25 }
variable "rf_5_dca_interval"            { type = number; default = 600 }
