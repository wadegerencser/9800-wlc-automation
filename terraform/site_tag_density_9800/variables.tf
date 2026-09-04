###############################################################################
# Variables – Site Tag Density Templates
# Cisco Catalyst 9800 WLC — sac-mgerencs-9800-wlc-automation
###############################################################################

variable "wlc_host" {
  description = "Hostname or IP of the Catalyst 9800 WLC (RESTCONF endpoint)"
  type        = string
}

variable "wlc_username" {
  description = "WLC management username"
  type        = string
  default     = "admin"
}

variable "wlc_password" {
  description = "WLC management password — use TF_VAR_wlc_password env var in production"
  type        = string
  sensitive   = true
}

# ── 2.4 GHz RF profiles ───────────────────────────────────────────────────────

variable "rf_profiles_24ghz" {
  description = "List of 2.4 GHz RF profile definitions (one per density tier)"
  type = list(object({
    name                 = string
    description          = string
    min_tx_power         = number
    max_tx_power         = number
    tpc_threshold        = number
    rx_sop_threshold     = string
    max_clients_per_radio = number
    disable_rates        = list(string)
    mandatory_rates      = list(string)
  }))
  default = [
    {
      name                  = "RF-2.4GHz-Low-Density"
      description           = "2.4 GHz — low-density, max coverage"
      min_tx_power          = 7
      max_tx_power          = 20
      tpc_threshold         = -72
      rx_sop_threshold      = "low"
      max_clients_per_radio = 200
      disable_rates         = ["1", "2", "5.5"]
      mandatory_rates       = ["11"]
    },
    {
      name                  = "RF-2.4GHz-Typical-Density"
      description           = "2.4 GHz — typical-density, band-steer to 5/6 GHz"
      min_tx_power          = 7
      max_tx_power          = 17
      tpc_threshold         = -70
      rx_sop_threshold      = "medium"
      max_clients_per_radio = 200
      disable_rates         = ["1", "2", "5.5"]
      mandatory_rates       = ["11"]
    },
    {
      name                  = "RF-2.4GHz-High-Density"
      description           = "2.4 GHz — high-density, legacy fallback only"
      min_tx_power          = 5
      max_tx_power          = 14
      tpc_threshold         = -67
      rx_sop_threshold      = "high"
      max_clients_per_radio = 100
      disable_rates         = ["1", "2", "5.5", "6", "9"]
      mandatory_rates       = ["12"]
    },
  ]
}

# ── 5 GHz RF profiles ─────────────────────────────────────────────────────────

variable "rf_profiles_5ghz" {
  description = "List of 5 GHz RF profile definitions (one per density tier)"
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
    {
      name                  = "RF-5GHz-Low-Density"
      description           = "5 GHz — low-density, 80 MHz channel width"
      min_tx_power          = 8
      max_tx_power          = 20
      tpc_threshold         = -72
      rx_sop_threshold      = "low"
      max_clients_per_radio = 200
      channel_width         = "80"
      disable_rates         = ["6", "9"]
      mandatory_rates       = ["12"]
    },
    {
      name                  = "RF-5GHz-Typical-Density"
      description           = "5 GHz — typical-density, 80 MHz, 802.11r/k/v roaming"
      min_tx_power          = 8
      max_tx_power          = 17
      tpc_threshold         = -70
      rx_sop_threshold      = "medium"
      max_clients_per_radio = 200
      channel_width         = "best"
      disable_rates         = ["6", "9"]
      mandatory_rates       = ["12", "24"]
    },
    {
      name                  = "RF-5GHz-High-Density"
      description           = "5 GHz — high-density, 40 MHz, 24 Mbps min, strict RX-SOP"
      min_tx_power          = 5
      max_tx_power          = 14
      tpc_threshold         = -67
      rx_sop_threshold      = "high"
      max_clients_per_radio = 100
      channel_width         = "40"
      disable_rates         = ["6", "9", "12", "18"]
      mandatory_rates       = ["24"]
    },
  ]
}

# ── 6 GHz RF profiles ─────────────────────────────────────────────────────────

variable "rf_profiles_6ghz" {
  description = "List of 6 GHz RF profile definitions (one per density tier)"
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
    {
      name                  = "RF-6GHz-Low-Density"
      description           = "6 GHz — low-density, Wi-Fi 6E LPI, 80 MHz"
      min_tx_power          = 5
      max_tx_power          = 23
      tpc_threshold         = -72
      rx_sop_threshold      = "low"
      max_clients_per_radio = 200
      channel_width         = "80"
      disable_rates         = ["6", "9"]
      mandatory_rates       = ["12"]
      bss_color_enable      = true
      twt_broadcast         = false
      ofdma_downlink        = true
      ofdma_uplink          = true
      mu_mimo_downlink      = true
      mu_mimo_uplink        = true
    },
    {
      name                  = "RF-6GHz-Typical-Density"
      description           = "6 GHz — typical-density, Wi-Fi 6E LPI, BSS color + TWT"
      min_tx_power          = 5
      max_tx_power          = 20
      tpc_threshold         = -70
      rx_sop_threshold      = "medium"
      max_clients_per_radio = 200
      channel_width         = "80"
      disable_rates         = ["6", "9"]
      mandatory_rates       = ["12", "24"]
      bss_color_enable      = true
      twt_broadcast         = true
      ofdma_downlink        = true
      ofdma_uplink          = true
      mu_mimo_downlink      = true
      mu_mimo_uplink        = true
    },
    {
      name                  = "RF-6GHz-High-Density"
      description           = "6 GHz — high-density, Wi-Fi 6E LPI, 80/160 MHz, PSD-aware"
      min_tx_power          = 3
      max_tx_power          = 17
      tpc_threshold         = -67
      rx_sop_threshold      = "high"
      max_clients_per_radio = 100
      channel_width         = "80"
      disable_rates         = ["6", "9", "12"]
      mandatory_rates       = ["18", "24"]
      bss_color_enable      = true
      twt_broadcast         = true
      ofdma_downlink        = true
      ofdma_uplink          = true
      mu_mimo_downlink      = true
      mu_mimo_uplink        = true
    },
  ]
}

# ── RF tags ───────────────────────────────────────────────────────────────────

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
    {
      name             = "RF-Tag-Low-Density"
      description      = "RF tag — low-density sites (warehouses, sparse offices)"
      rf_profile_24ghz = "RF-2.4GHz-Low-Density"
      rf_profile_5ghz  = "RF-5GHz-Low-Density"
      rf_profile_6ghz  = "RF-6GHz-Low-Density"
    },
    {
      name             = "RF-Tag-Typical-Density"
      description      = "RF tag — typical-density sites (offices, K-12, campus)"
      rf_profile_24ghz = "RF-2.4GHz-Typical-Density"
      rf_profile_5ghz  = "RF-5GHz-Typical-Density"
      rf_profile_6ghz  = "RF-6GHz-Typical-Density"
    },
    {
      name             = "RF-Tag-High-Density"
      description      = "RF tag — high-density sites (stadiums, transit, auditoriums)"
      rf_profile_24ghz = "RF-2.4GHz-High-Density"
      rf_profile_5ghz  = "RF-5GHz-High-Density"
      rf_profile_6ghz  = "RF-6GHz-High-Density"
    },
  ]
}

# ── Density site tags ─────────────────────────────────────────────────────────

variable "density_site_tags" {
  description = "Site tag definitions per density tier"
  type = list(object({
    name                 = string
    description          = string
    ap_profile           = string
    local_site           = bool
    flex_profile         = string
    recommended_rf_tag   = string
    density_tier         = string
  }))
  default = [
    {
      name               = "Site-Low-Density"
      description        = "Low-density site — warehouse / lobby / sparse office"
      ap_profile         = "AP-Join-Standard"
      local_site         = false
      flex_profile       = ""
      recommended_rf_tag = "RF-Tag-Low-Density"
      density_tier       = "low"
    },
    {
      name               = "Site-Low-Density-Flex"
      description        = "Low-density FlexConnect — remote branch / warehouse"
      ap_profile         = "AP-Join-Standard"
      local_site         = true
      flex_profile       = "Flex-Branch"
      recommended_rf_tag = "RF-Tag-Low-Density"
      density_tier       = "low"
    },
    {
      name               = "Site-Typical-Density"
      description        = "Typical-density site — office / K-12 / campus building"
      ap_profile         = "AP-Join-Standard"
      local_site         = false
      flex_profile       = ""
      recommended_rf_tag = "RF-Tag-Typical-Density"
      density_tier       = "typical"
    },
    {
      name               = "Site-Typical-Density-Flex"
      description        = "Typical-density FlexConnect — regional office / clinic"
      ap_profile         = "AP-Join-Standard"
      local_site         = true
      flex_profile       = "Flex-Branch"
      recommended_rf_tag = "RF-Tag-Typical-Density"
      density_tier       = "typical"
    },
    {
      name               = "Site-High-Density"
      description        = "High-density site — transit / stadium / auditorium"
      ap_profile         = "AP-Join-Standard"
      local_site         = false
      flex_profile       = ""
      recommended_rf_tag = "RF-Tag-High-Density"
      density_tier       = "high"
    },
    {
      name               = "Site-High-Density-Central"
      description        = "High-density central-switch — campus core"
      ap_profile         = "AP-Join-Standard"
      local_site         = false
      flex_profile       = ""
      recommended_rf_tag = "RF-Tag-High-Density"
      density_tier       = "high"
    },
  ]
}
