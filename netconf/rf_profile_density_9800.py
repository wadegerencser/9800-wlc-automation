# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
RF Profile Density Automation via NETCONF – Cisco Catalyst 9800 WLC

Pushes density-aware RF profiles (2.4 / 5 / 6 GHz), RF tags, and site tags
from vars/rf_profile_density_defaults.yml and vars/site_tag_density_defaults.yml
using NETCONF edit-config with Cisco IOS-XE YANG models.

Three density tiers: low / typical / high.
6 GHz profiles include BSS Color, TWT, OFDMA, and LPI PSD constraints.

Requires: pip install ncclient pyyaml

── Platform Install ──────────────────────────────────────────────────────────

  macOS / Linux
    pip install ncclient pyyaml
    python3 netconf/rf_profile_density_9800.py --host 192.168.1.1 --user admin

  Windows (PowerShell or Command Prompt — native Python, no WSL needed)
    pip install ncclient pyyaml
    python netconf\\rf_profile_density_9800.py --host 192.168.1.1 --user admin

  Android / iOS / NPC / tablet
    Use SSH client (Termius, Blink Shell) → jump host → run macOS/Linux command.
    Or trigger via Ansible Automation Platform job (no local Python needed).

  Dry-run (print NETCONF payloads, no connection):
    python3 netconf/rf_profile_density_9800.py --dry-run

  Single density tier only:
    python3 netconf/rf_profile_density_9800.py --host 192.168.1.1 --density high

──────────────────────────────────────────────────────────────────────────────
"""

import argparse
import getpass
import sys
from textwrap import dedent

try:
    from ncclient import manager
    from ncclient.operations import RPCError
except ImportError:
    print("ERROR: ncclient not installed — run: pip install ncclient", file=sys.stderr)
    sys.exit(1)

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml not installed — run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

NETCONF_PORT = 830
YANG_RF   = "http://cisco.com/ns/yang/Cisco-IOS-XE-wireless-rf-cfg"
YANG_SITE = "http://cisco.com/ns/yang/Cisco-IOS-XE-wireless-site-cfg"

DENSITY_TIERS = ("low", "typical", "high")

# ── YANG payload builders ─────────────────────────────────────────────────────

def _band_code(band: str) -> str:
    return {"24": "dot11-2-dot-4-ghz-band", "5": "dot11-5-ghz-band", "6": "dot11-6-ghz-band"}[band]


def _rf_profile_payload(band: str, name: str, description: str,
                         min_tx: int, max_tx: int, tpc: int,
                         rx_sop: str, max_clients: int,
                         channel_width: str = "",
                         bss_color: bool = False,
                         twt: bool = False,
                         ofdma_dl: bool = False,
                         ofdma_ul: bool = False,
                         mu_mimo_dl: bool = False,
                         mu_mimo_ul: bool = False) -> str:
    chan_elem = f"<chan-width>{channel_width}</chan-width>" if channel_width else ""
    ax_elems = ""
    if band == "6":
        ax_elems = dedent(f"""\
                <dot11ax-bss-color-enable>{'true' if bss_color else 'false'}</dot11ax-bss-color-enable>
                <dot11ax-twt-broadcast>{'true' if twt else 'false'}</dot11ax-twt-broadcast>
                <dot11ax-ofdma-dl>{'true' if ofdma_dl else 'false'}</dot11ax-ofdma-dl>
                <dot11ax-ofdma-ul>{'true' if ofdma_ul else 'false'}</dot11ax-ofdma-ul>
                <dot11ax-mu-mimo-dl>{'true' if mu_mimo_dl else 'false'}</dot11ax-mu-mimo-dl>
                <dot11ax-mu-mimo-ul>{'true' if mu_mimo_ul else 'false'}</dot11ax-mu-mimo-ul>""")
    return dedent(f"""\
        <config>
          <rf-cfg-data xmlns="{YANG_RF}">
            <rf-profiles>
              <rf-profile>
                <rf-profile-name>{name}</rf-profile-name>
                <description>{description}</description>
                <band>{_band_code(band)}</band>
                <tx-power-min>{min_tx}</tx-power-min>
                <tx-power-max>{max_tx}</tx-power-max>
                <tpc-ver1-thresh>{tpc}</tpc-ver1-thresh>
                <rx-sop-threshold>{rx_sop}</rx-sop-threshold>
                <max-client-limit>{max_clients}</max-client-limit>
                {chan_elem}
                {ax_elems}
              </rf-profile>
            </rf-profiles>
          </rf-cfg-data>
        </config>""")


def _rf_tag_payload(name: str, description: str,
                    profile_24: str, profile_5: str, profile_6: str) -> str:
    return dedent(f"""\
        <config>
          <site-cfg-data xmlns="{YANG_SITE}">
            <rf-tag-configs>
              <rf-tag-config>
                <rf-tag-name>{name}</rf-tag-name>
                <description>{description}</description>
                <dot11-24ghz-policy>{profile_24}</dot11-24ghz-policy>
                <dot11-5ghz-policy>{profile_5}</dot11-5ghz-policy>
                <dot11-6ghz-policy>{profile_6}</dot11-6ghz-policy>
              </rf-tag-config>
            </rf-tag-configs>
          </site-cfg-data>
        </config>""")


def _site_tag_payload(tag: dict) -> str:
    local_elem = "<local-site/>" if tag.get("local_site") else ""
    flex_elem  = f"<flex-profile>{tag['flex_profile']}</flex-profile>" \
                 if tag.get("flex_profile") else ""
    return dedent(f"""\
        <config>
          <site-cfg-data xmlns="{YANG_SITE}">
            <site-tag-configs>
              <site-tag-config>
                <site-tag-name>{tag['name']}</site-tag-name>
                <description>{tag.get('description', '')}</description>
                <ap-profile>{tag['ap_profile']}</ap-profile>
                {local_elem}
                {flex_elem}
              </site-tag-config>
            </site-tag-configs>
          </site-cfg-data>
        </config>""")


# ── Dispatch helpers ──────────────────────────────────────────────────────────

def _push_or_print(nc, payload: str, label: str, dry_run: bool) -> None:
    if dry_run:
        print(f"\n── {label} ──\n{payload}")
        return
    nc.edit_config(target="running", config=payload)
    print(f"  ✓ {label}")


def _density_key(tier: str, band: str, key: str, data: dict):
    """Resolve a density var key like rf_<tier>_<band>_<key> from flat vars dict."""
    band_map = {"24": "24", "5": "5", "6": "6"}
    return data.get(f"rf_{tier}_{band_map[band]}_{key}")


# ── Main provisioning logic ───────────────────────────────────────────────────

def provision(nc_or_none, data_rf: dict, data_site: dict,
              densities: list, dry_run: bool) -> None:

    for tier in densities:
        print(f"\n── Tier: {tier.upper()} ─────────────────────────────────────")

        # ── 2.4 GHz RF profile ───────────────────────────────────────────────
        payload = _rf_profile_payload(
            band        = "24",
            name        = data_rf[f"rf_{tier}_24ghz_name"],
            description = data_rf[f"rf_{tier}_24ghz_description"],
            min_tx      = data_rf[f"rf_{tier}_24_min_tx_power"],
            max_tx      = data_rf[f"rf_{tier}_24_max_tx_power"],
            tpc         = data_rf[f"rf_{tier}_24_tpc_threshold"],
            rx_sop      = data_rf[f"rf_{tier}_24_rx_sop_threshold"],
            max_clients = data_rf[f"rf_{tier}_24_max_clients_per_radio"],
        )
        _push_or_print(nc_or_none, payload,
                       f"2.4 GHz RF profile — {data_rf[f'rf_{tier}_24ghz_name']}", dry_run)

        # ── 5 GHz RF profile ─────────────────────────────────────────────────
        payload = _rf_profile_payload(
            band          = "5",
            name          = data_rf[f"rf_{tier}_5ghz_name"],
            description   = data_rf[f"rf_{tier}_5ghz_description"],
            min_tx        = data_rf[f"rf_{tier}_5_min_tx_power"],
            max_tx        = data_rf[f"rf_{tier}_5_max_tx_power"],
            tpc           = data_rf[f"rf_{tier}_5_tpc_threshold"],
            rx_sop        = data_rf[f"rf_{tier}_5_rx_sop_threshold"],
            max_clients   = data_rf[f"rf_{tier}_5_max_clients_per_radio"],
            channel_width = data_rf[f"rf_{tier}_5_channel_width"],
        )
        _push_or_print(nc_or_none, payload,
                       f"5 GHz RF profile — {data_rf[f'rf_{tier}_5ghz_name']}", dry_run)

        # ── 6 GHz RF profile (Wi-Fi 6E LPI) ─────────────────────────────────
        payload = _rf_profile_payload(
            band          = "6",
            name          = data_rf[f"rf_{tier}_6ghz_name"],
            description   = data_rf[f"rf_{tier}_6ghz_description"],
            min_tx        = data_rf[f"rf_{tier}_6_min_tx_power"],
            max_tx        = data_rf[f"rf_{tier}_6_max_tx_power"],
            tpc           = data_rf[f"rf_{tier}_6_tpc_threshold"],
            rx_sop        = data_rf[f"rf_{tier}_6_rx_sop_threshold"],
            max_clients   = data_rf[f"rf_{tier}_6_max_clients_per_radio"],
            channel_width = data_rf[f"rf_{tier}_6_channel_width"],
            bss_color     = data_rf.get(f"rf_{tier}_6_bss_color_enable", True),
            twt           = data_rf.get(f"rf_{tier}_6_twt_broadcast", False),
            ofdma_dl      = data_rf.get(f"rf_{tier}_6_ofdma_downlink", True),
            ofdma_ul      = data_rf.get(f"rf_{tier}_6_ofdma_uplink", True),
            mu_mimo_dl    = data_rf.get(f"rf_{tier}_6_mu_mimo_downlink", True),
            mu_mimo_ul    = data_rf.get(f"rf_{tier}_6_mu_mimo_uplink", True),
        )
        _push_or_print(nc_or_none, payload,
                       f"6 GHz RF profile — {data_rf[f'rf_{tier}_6ghz_name']}", dry_run)

    # ── RF tags ──────────────────────────────────────────────────────────────
    print("\n── RF Tags ──────────────────────────────────────────────────────")
    for tag in data_rf.get("rf_tags", []):
        if not any(tier in tag["name"].lower() for tier in densities):
            continue
        payload = _rf_tag_payload(
            name        = tag["name"],
            description = tag["description"],
            profile_24  = tag["rf_profile_24ghz"],
            profile_5   = tag["rf_profile_5ghz"],
            profile_6   = tag["rf_profile_6ghz"],
        )
        _push_or_print(nc_or_none, payload, f"RF tag — {tag['name']}", dry_run)

    # ── Site tags ─────────────────────────────────────────────────────────────
    if data_site:
        print("\n── Site Tags ────────────────────────────────────────────────────")
        for tag in data_site.get("density_site_tags", []):
            if tag.get("density_tier") not in densities:
                continue
            payload = _site_tag_payload(tag)
            _push_or_print(nc_or_none, payload, f"Site tag — {tag['name']}", dry_run)


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    p = argparse.ArgumentParser(
        description="Push density RF profiles, RF tags, and site tags to Cisco 9800 via NETCONF"
    )
    p.add_argument("--host",      default="",     help="WLC IP / hostname")
    p.add_argument("--user",      default="admin")
    p.add_argument("--password",  default="",     help="Leave blank to prompt")
    p.add_argument("--dry-run",   action="store_true", help="Print payloads, no connection")
    p.add_argument("--density",   default="all",
                   choices=["all", "low", "typical", "high"],
                   help="Provision a single density tier (default: all)")
    p.add_argument("--rf-vars",   default="vars/rf_profile_density_defaults.yml")
    p.add_argument("--site-vars", default="vars/site_tag_density_defaults.yml",
                   help="Path to site tag density vars (optional — omit to skip site tags)")
    args = p.parse_args()

    if not args.dry_run and not args.host:
        p.error("--host is required unless --dry-run is specified")

    # Load vars
    with open(args.rf_vars) as f:
        data_rf = yaml.safe_load(f)

    data_site = {}
    try:
        with open(args.site_vars) as f:
            data_site = yaml.safe_load(f)
    except FileNotFoundError:
        pass  # site tags are optional

    densities = list(DENSITY_TIERS) if args.density == "all" else [args.density]

    password = args.password or (
        getpass.getpass(f"Password for {args.user}@{args.host}: ")
        if not args.dry_run else ""
    )

    if args.dry_run:
        provision(None, data_rf, data_site, densities, dry_run=True)
        return

    print(f"Connecting to {args.host}:{NETCONF_PORT} as {args.user} …")
    try:
        with manager.connect(
            host=args.host,
            port=NETCONF_PORT,
            username=args.user,
            password=password,
            hostkey_verify=False,
            device_params={"name": "iosxe"},
            timeout=30,
        ) as nc:
            provision(nc, data_rf, data_site, densities, dry_run=False)
            print("\nAll density profiles applied successfully.")
    except RPCError as exc:
        print(f"NETCONF RPC error: {exc.message}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted.")


if __name__ == "__main__":
    main()
