# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
RF Profile Hardening via NETCONF – Cisco Catalyst 9800 WLC

Pushes 2.4 GHz and 5 GHz RF profile configuration to a 9800 controller using
NETCONF edit-config and Cisco-IOS-XE-wireless YANG models.

Requires: pip install ncclient

── Platform Install ──────────────────────────────────────────────────────────

  macOS / Linux
    pip install ncclient
    python3 netconf/rf_profile_harden_9800.py --host 192.168.1.1 --user admin

  Windows (PowerShell or Command Prompt — native Python, no WSL needed)
    pip install ncclient
    python netconf\\rf_profile_harden_9800.py --host 192.168.1.1 --user admin

  Dry-run (print payloads, no connection):
    python3 netconf/rf_profile_harden_9800.py --dry-run

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

NETCONF_PORT = 830
YANG_RF = "http://cisco.com/ns/yang/Cisco-IOS-XE-wireless-rf-cfg"


def _rf_profile_payload(band: str, profile_name: str, description: str,
                         min_power: int, max_power: int,
                         max_clients: int, channel_width: str = "20") -> str:
    width_elem = f"<chan-width>{channel_width}</chan-width>" if band == "5ghz" else ""
    return dedent(f"""\
        <config>
          <rf-cfg-data xmlns="{YANG_RF}">
            <rf-profiles>
              <rf-profile>
                <profile-name>{profile_name}</profile-name>
                <band>{band}</band>
                <description>{description}</description>
                <tx-power-min>{min_power}</tx-power-min>
                <tx-power-max>{max_power}</tx-power-max>
                <max-clients-per-radio>{max_clients}</max-clients-per-radio>
                {width_elem}
                <status>true</status>
              </rf-profile>
            </rf-profiles>
          </rf-cfg-data>
        </config>""")


def run(args: argparse.Namespace, password: str) -> None:
    steps = [
        ("2.4 GHz RF profile", _rf_profile_payload(
            "24ghz", args.profile_24ghz, "2.4 GHz RF Profile - NaC managed",
            args.min_power_24, args.max_power_24, args.max_clients_24
        )),
        ("5 GHz RF profile", _rf_profile_payload(
            "5ghz", args.profile_5ghz, "5 GHz RF Profile - NaC managed",
            args.min_power_5, args.max_power_5, args.max_clients_5,
            args.channel_width
        )),
    ]

    if args.dry_run:
        print("── DRY RUN — payloads only, no connection ──")
        for label, payload in steps:
            print(f"\n{'─'*60}\n# {label}\n{'─'*60}\n{payload}")
        return

    print(f"Connecting to {args.host}:{NETCONF_PORT} as {args.user} …")
    with manager.connect(
        host=args.host,
        port=NETCONF_PORT,
        username=args.user,
        password=password,
        hostkey_verify=False,
        device_params={"name": "iosxe"},
        timeout=30,
    ) as nc:
        for label, payload in steps:
            print(f"  Applying: {label} …")
            nc.edit_config(target="running", config=payload)
        print("\nRF profile hardening complete.")


def main() -> None:
    p = argparse.ArgumentParser(description="Push RF profile hardening to Cisco 9800 WLC via NETCONF")
    p.add_argument("--host",          default="",              help="WLC IP / hostname")
    p.add_argument("--user",          default="admin",         help="NETCONF username")
    p.add_argument("--password",      default="",              help="Leave blank to prompt")
    p.add_argument("--dry-run",       action="store_true",     help="Print payloads without connecting")
    p.add_argument("--profile-24ghz", default="RF-2.4GHz-Standard")
    p.add_argument("--profile-5ghz",  default="RF-5GHz-Standard")
    p.add_argument("--min-power-24",  type=int, default=7)
    p.add_argument("--max-power-24",  type=int, default=17)
    p.add_argument("--max-clients-24",type=int, default=200)
    p.add_argument("--min-power-5",   type=int, default=8)
    p.add_argument("--max-power-5",   type=int, default=17)
    p.add_argument("--max-clients-5", type=int, default=200)
    p.add_argument("--channel-width", default="best",
                   choices=["20", "40", "80", "best"])

    args = p.parse_args()
    if not args.dry_run and not args.host:
        p.error("--host is required unless --dry-run is specified")

    password = args.password or (
        getpass.getpass(f"Password for {args.user}@{args.host}: ")
        if not args.dry_run else ""
    )

    try:
        run(args, password)
    except RPCError as exc:
        print(f"NETCONF RPC error: {exc.message}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted.")


if __name__ == "__main__":
    main()
