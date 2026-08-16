# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
WPA3 SSID Adoption via NETCONF – Cisco Catalyst 9800 WLC

Pushes a WPA3 WLAN configuration to an IOS-XE 9800 controller using
NETCONF edit-config and the Cisco-IOS-XE-wireless-wlan-cfg YANG model.

Supported modes (--mode):
  personal    WPA3-Personal (SAE) — PMF required
  enterprise  WPA3-Enterprise (802.1X) — PMF required
  transition  WPA2+WPA3 mixed — PMF optional

Requires: pip install ncclient

── Platform Install ──────────────────────────────────────────────────────────

  macOS / Linux
    pip install ncclient
    python3 wpa3_ssid_netconf.py --host 192.168.1.1 --user admin \\
        --ssid CORP-WPA3 --wlan-id 1 --mode personal

  Windows (PowerShell or Command Prompt — native Python, no WSL needed)
    pip install ncclient
    python wpa3_ssid_netconf.py --host 192.168.1.1 --user admin ^
        --ssid CORP-WPA3 --wlan-id 1 --mode personal

  NOTE: omit --password to be prompted securely; never pass credentials
  on the command line on shared hosts (visible in process list).

  WARNING: hostkey_verify is disabled — use only on trusted lab networks.

─────────────────────────────────────────────────────────────────────────────
"""

import argparse
import getpass
import sys
from textwrap import dedent

from ncclient import manager
from ncclient.operations import RPCError

NETCONF_PORT = 830
YANG_NS = "http://cisco.com/ns/yang/Cisco-IOS-XE-wireless-wlan-cfg"

# ── YANG payloads ─────────────────────────────────────────────────────────────

def _wlan_config_personal(wlan_name: str, wlan_id: int, ssid: str, passphrase: str, vlan: int) -> str:
    return dedent(f"""\
        <config>
          <wlan-cfg-data xmlns="{YANG_NS}">
            <wlan-cfg-entries>
              <wlan-cfg-entry>
                <profile-name>{wlan_name}</profile-name>
                <wlan-id>{wlan_id}</wlan-id>
                <ssid>{ssid}</ssid>
                <status>true</status>
                <wlan-policy-vlan>{vlan}</wlan-policy-vlan>
                <wpa-cfg>
                  <wpa-version>wpa3-personal</wpa-version>
                  <akm-cfg>
                    <psk-enabled>false</psk-enabled>
                    <sae-enabled>true</sae-enabled>
                  </akm-cfg>
                  <pmf-cfg>
                    <pmf-state>required</pmf-state>
                  </pmf-cfg>
                  <psk-cfg>
                    <psk-type>ascii</psk-type>
                    <psk-value>{passphrase}</psk-value>
                  </psk-cfg>
                </wpa-cfg>
              </wlan-cfg-entry>
            </wlan-cfg-entries>
          </wlan-cfg-data>
        </config>""")


def _wlan_config_enterprise(wlan_name: str, wlan_id: int, ssid: str, vlan: int, method_list: str) -> str:
    return dedent(f"""\
        <config>
          <wlan-cfg-data xmlns="{YANG_NS}">
            <wlan-cfg-entries>
              <wlan-cfg-entry>
                <profile-name>{wlan_name}</profile-name>
                <wlan-id>{wlan_id}</wlan-id>
                <ssid>{ssid}</ssid>
                <status>true</status>
                <wlan-policy-vlan>{vlan}</wlan-policy-vlan>
                <wpa-cfg>
                  <wpa-version>wpa3-enterprise</wpa-version>
                  <akm-cfg>
                    <dot1x-enabled>true</dot1x-enabled>
                    <psk-enabled>false</psk-enabled>
                  </akm-cfg>
                  <pmf-cfg>
                    <pmf-state>required</pmf-state>
                  </pmf-cfg>
                </wpa-cfg>
                <dot1x-cfg>
                  <auth-list>{method_list}</auth-list>
                </dot1x-cfg>
              </wlan-cfg-entry>
            </wlan-cfg-entries>
          </wlan-cfg-data>
        </config>""")


def _wlan_config_transition(wlan_name: str, wlan_id: int, ssid: str, passphrase: str, vlan: int) -> str:
    return dedent(f"""\
        <config>
          <wlan-cfg-data xmlns="{YANG_NS}">
            <wlan-cfg-entries>
              <wlan-cfg-entry>
                <profile-name>{wlan_name}</profile-name>
                <wlan-id>{wlan_id}</wlan-id>
                <ssid>{ssid}</ssid>
                <status>true</status>
                <wlan-policy-vlan>{vlan}</wlan-policy-vlan>
                <wpa-cfg>
                  <wpa-version>wpa2-wpa3-transition</wpa-version>
                  <akm-cfg>
                    <psk-enabled>true</psk-enabled>
                    <sae-enabled>true</sae-enabled>
                  </akm-cfg>
                  <pmf-cfg>
                    <pmf-state>optional</pmf-state>
                  </pmf-cfg>
                  <psk-cfg>
                    <psk-type>ascii</psk-type>
                    <psk-value>{passphrase}</psk-value>
                  </psk-cfg>
                </wpa-cfg>
              </wlan-cfg-entry>
            </wlan-cfg-entries>
          </wlan-cfg-data>
        </config>""")


def push_wlan(args: argparse.Namespace, password: str) -> None:
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
        print(f"Connected. Pushing WPA3 WLAN '{args.wlan_name}' (mode: {args.mode}) …")

        if args.mode == "personal":
            payload = _wlan_config_personal(
                args.wlan_name, args.wlan_id, args.ssid, args.passphrase, args.vlan
            )
        elif args.mode == "enterprise":
            payload = _wlan_config_enterprise(
                args.wlan_name, args.wlan_id, args.ssid, args.vlan, args.method_list
            )
        else:
            payload = _wlan_config_transition(
                args.wlan_name, args.wlan_id, args.ssid, args.passphrase, args.vlan
            )

        nc.edit_config(target="running", config=payload)
        print(f"WLAN '{args.wlan_name}' (SSID: {args.ssid}) committed successfully.")


def main() -> None:
    p = argparse.ArgumentParser(
        description="Push a WPA3 WLAN to a Cisco 9800 WLC via NETCONF"
    )
    p.add_argument("--host",        required=True,  help="WLC IP / hostname")
    p.add_argument("--user",        required=True,  help="SSH/NETCONF username")
    p.add_argument("--password",    default="",     help="Leave blank to prompt")
    p.add_argument("--mode",        default="personal",
                   choices=["personal", "enterprise", "transition"],
                   help="WPA3 deployment mode (default: personal)")
    p.add_argument("--ssid",        default="CORP-WPA3",      help="SSID broadcast name")
    p.add_argument("--wlan-name",   default="wpa3-adoption",  help="WLAN profile name")
    p.add_argument("--wlan-id",     type=int, default=1,      help="WLAN ID (1–512)")
    p.add_argument("--vlan",        type=int, default=100,    help="Client VLAN ID")
    p.add_argument("--passphrase",  default="ChangeMe-Str0ng!",
                   help="SAE/PSK passphrase (personal and transition modes)")
    p.add_argument("--method-list", default="dot1x-WPA3",
                   help="AAA dot1x method list name (enterprise mode)")

    args = p.parse_args()
    password = args.password or getpass.getpass(f"Password for {args.user}@{args.host}: ")

    try:
        push_wlan(args, password)
    except RPCError as exc:
        print(f"NETCONF RPC error: {exc.message}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted.")


if __name__ == "__main__":
    main()
