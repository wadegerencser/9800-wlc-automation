# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# =============================================================================

variable "wlc_host"     { type = string; description = "9800 WLC IP or hostname" }
variable "wlc_username" { type = string; description = "WLC management username" }
variable "wlc_password" { type = string; sensitive = true; description = "WLC management password — use TF_VAR_wlc_password" }

variable "rf_profiles_24ghz" {
  description = "2.4 GHz RF profiles — one per density tier"
  type = list(object({
    name                  = string
    description           = string
    min_tx_power          = number
    max_tx_power          = number
    tpc_threshold         = number
    rx_sop_threshold      = string
    max_clients_per_radio = number
    disable_rates         = list(string)
    mandatory_rates       = list(string)
  }))
  default = [
    { name = "RF-2.4GHz-Low-Density"     description = "2.4 GHz low-density RF profile — NaC managed"     min_tx_power = 7 max_tx_power = 20 tpc_threshold = -72 rx_sop_threshold = "low"    max_clients_per_radio = 200 disable_rates = ["1","2","5.5"]       mandatory_rates = ["11"] },
    { name = "RF-2.4GHz-Typical-Density" description = "2.4 GHz typical-density RF profile — NaC managed" min_tx_power = 7 max_tx_power = 17 tpc_threshold = -70 rx_sop_threshold = "medium" max_clients_per_radio = 200 disable_rates = ["1","2","5.5"]       mandatory_rates = ["11"] },
    { name = "RF-2.4GHz-High-Density"    description = "2.4 GHz high-density RF profile — NaC managed"    min_tx_power = 5 max_tx_power = 14 tpc_threshold = -67 rx_sop_threshold = "high"   max_clients_per_radio = 100 disable_rates = ["1","2","5.5","6","9"] mandatory_rates = ["12"] },
  ]
}

variable "rf_profiles_5ghz" {
  description = "5 GHz RF profiles — one per density tier"
  type = list(object({
    name                  = string
    description           = string
    min_tx_power          = number
    max_tx_power          = number
    tpc_threshold         = number
    rx_sop_threshold      = string
    max_clients_per_radio = number
    channel_width         = string
    disable_rates         = list(string)
    mandatory_rates       = list(string)
  }))
  default = [
    { name = "RF-5GHz-Low-Density"     description = "5 GHz low-density RF profile — NaC managed"     min_tx_power = 8 max_tx_power = 20 tpc_threshold = -72 rx_sop_threshold = "low"    max_clients_per_radio = 200 channel_width = "80"   disable_rates = ["6","9"]        mandatory_rates = ["12"] },
    { name = "RF-5GHz-Typical-Density" description = "5 GHz typical-density RF profile — NaC managed" min_tx_power = 8 max_tx_power = 17 tpc_threshold = -70 rx_sop_threshold = "medium" max_clients_per_radio = 200 channel_width = "best" disable_rates = ["6","9"]        mandatory_rates = ["12","24"] },
    { name = "RF-5GHz-High-Density"    description = "5 GHz high-density RF profile — NaC managed"    min_tx_power = 5 max_tx_power = 14 tpc_threshold = -67 rx_sop_threshold = "high"   max_clients_per_radio = 100 channel_width = "40"   disable_rates = ["6","9","12","18"] mandatory_rates = ["24"] },
  ]
}

variable "rf_profiles_6ghz" {
  description = "6 GHz RF profiles — one per density tier (Wi-Fi 6E LPI, 802.11ax)"
  type = list(object({
    name                  = string
    description           = string
    min_tx_power          = number
    max_tx_power          = number
    tpc_threshold         = number
    rx_sop_threshold      = string
    max_clients_per_radio = number
    channel_width         = string
    disable_rates         = list(string)
    mandatory_rates       = list(string)
    bss_color_enable      = bool
    twt_broadcast         = bool
    ofdma_downlink        = bool
    ofdma_uplink          = bool
    mu_mimo_downlink      = bool
    mu_mimo_uplink        = bool
  }))
  default = [
    { name = "RF-6GHz-Low-Density"     description = "6 GHz low-density RF profile — NaC managed"     min_tx_power = 5 max_tx_power = 23 tpc_threshold = -72 rx_sop_threshold = "low"    max_clients_per_radio = 200 channel_width = "80" disable_rates = ["6","9"]      mandatory_rates = ["12"]      bss_color_enable = true twt_broadcast = false ofdma_downlink = true ofdma_uplink = true mu_mimo_downlink = true mu_mimo_uplink = true },
    { name = "RF-6GHz-Typical-Density" description = "6 GHz typical-density RF profile — NaC managed" min_tx_power = 5 max_tx_power = 20 tpc_threshold = -70 rx_sop_threshold = "medium" max_clients_per_radio = 200 channel_width = "80" disable_rates = ["6","9"]      mandatory_rates = ["12","24"] bss_color_enable = true twt_broadcast = true  ofdma_downlink = true ofdma_uplink = true mu_mimo_downlink = true mu_mimo_uplink = true },
    { name = "RF-6GHz-High-Density"    description = "6 GHz high-density RF profile — NaC managed"    min_tx_power = 3 max_tx_power = 17 tpc_threshold = -67 rx_sop_threshold = "high"   max_clients_per_radio = 100 channel_width = "80" disable_rates = ["6","9","12"] mandatory_rates = ["18","24"] bss_color_enable = true twt_broadcast = true  ofdma_downlink = true ofdma_uplink = true mu_mimo_downlink = true mu_mimo_uplink = true },
  ]
}

variable "rf_tags" {
  description = "RF tags binding 2.4/5/6 GHz profiles per density tier"
  type = list(object({
    name             = string
    description      = string
    rf_profile_24ghz = string
    rf_profile_5ghz  = string
    rf_profile_6ghz  = string
  }))
  default = [
    { name = "RF-Tag-Low-Density"     description = "Low-density RF tag — NaC managed"     rf_profile_24ghz = "RF-2.4GHz-Low-Density"     rf_profile_5ghz = "RF-5GHz-Low-Density"     rf_profile_6ghz = "RF-6GHz-Low-Density" },
    { name = "RF-Tag-Typical-Density" description = "Typical-density RF tag — NaC managed" rf_profile_24ghz = "RF-2.4GHz-Typical-Density" rf_profile_5ghz = "RF-5GHz-Typical-Density" rf_profile_6ghz = "RF-6GHz-Typical-Density" },
    { name = "RF-Tag-High-Density"    description = "High-density RF tag — NaC managed"    rf_profile_24ghz = "RF-2.4GHz-High-Density"    rf_profile_5ghz = "RF-5GHz-High-Density"    rf_profile_6ghz = "RF-6GHz-High-Density" },
  ]
}

variable "density_site_tags" {
  description = "Site tag definitions per density tier"
  type = list(object({
    name               = string
    description        = string
    ap_profile         = string
    local_site         = bool
    flex_profile       = string
    recommended_rf_tag = string
    density_tier       = string
  }))
  default = [
    { name = "Site-Low-Density"             description = "Low-density site — NaC managed"                local_site = false flex_profile = ""             ap_profile = "AP-Join-Standard" recommended_rf_tag = "RF-Tag-Low-Density"     density_tier = "low" },
    { name = "Site-Low-Density-Flex"        description = "Low-density FlexConnect site — NaC managed"    local_site = true  flex_profile = "Flex-Branch"   ap_profile = "AP-Join-Standard" recommended_rf_tag = "RF-Tag-Low-Density"     density_tier = "low" },
    { name = "Site-Typical-Density"         description = "Typical-density site — NaC managed"            local_site = false flex_profile = ""             ap_profile = "AP-Join-Standard" recommended_rf_tag = "RF-Tag-Typical-Density" density_tier = "typical" },
    { name = "Site-Typical-Density-Flex"    description = "Typical-density FlexConnect site — NaC managed" local_site = true flex_profile = "Flex-Branch"   ap_profile = "AP-Join-Standard" recommended_rf_tag = "RF-Tag-Typical-Density" density_tier = "typical" },
    { name = "Site-High-Density"            description = "High-density site — NaC managed"               local_site = false flex_profile = ""             ap_profile = "AP-Join-Standard" recommended_rf_tag = "RF-Tag-High-Density"    density_tier = "high" },
    { name = "Site-High-Density-Central"    description = "High-density central-switch site — NaC managed" local_site = false flex_profile = ""             ap_profile = "AP-Join-Standard" recommended_rf_tag = "RF-Tag-High-Density"    density_tier = "high" },
  ]
}
