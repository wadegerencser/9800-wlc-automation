# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================

output "rf_profile_24ghz" { value = var.rf_profile_24ghz_name; description = "2.4 GHz RF profile name applied" }
output "rf_profile_5ghz"  { value = var.rf_profile_5ghz_name;  description = "5 GHz RF profile name applied" }
output "wlc_host"         { value = var.wlc_host;               description = "Target WLC" }
