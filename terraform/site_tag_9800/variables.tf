# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# =============================================================================

variable "wlc_host"     { type = string }
variable "wlc_username" { type = string }
variable "wlc_password" { type = string; sensitive = true }

variable "site_tags" {
  description = "List of site tags to create on the 9800 WLC"
  type = list(object({
    name         = string
    description  = string
    ap_profile   = string
    local_site   = bool
    flex_profile = string
  }))
  default = [
    {
      name         = "Site-HQ"
      description  = "Headquarters — NaC managed"
      ap_profile   = "AP-Join-Standard"
      local_site   = false
      flex_profile = ""
    },
    {
      name         = "Site-Branch-01"
      description  = "Branch Office 01 — NaC managed"
      ap_profile   = "AP-Join-Standard"
      local_site   = true
      flex_profile = "Flex-Branch"
    }
  ]
}
