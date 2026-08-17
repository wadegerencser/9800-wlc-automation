# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
AP Join Profile via NETCONF – Cisco Catalyst 9800 WLC

Pushes AP join profile configuration via NETCONF edit-config using
Cisco-IOS-XE-wireless-ap-cfg YANG models.

Requires: pip install ncclient

── Platform Install ──────────────────────────────────────────────────────────

  macOS / Linux
    pip install ncclient
    python3 netconf/ap_join_profile_9800.py --host 192.168.1.1 --user admin

  Windows (PowerShell or Command Prompt — native Python, no WSL needed)
    pip install ncclient
    python netconf\\ap_join_profile_9800.py --host 192.168.1.1 --user admin

  Dry-run (print payloads, no connection):
    python3 netconf/ap_join_profile_9800.py --dry-run

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
YANG_AP = "http://cisco.com/ns/yang/Cisco-IOS-XE-wireless-ap-cfg"


def _ap_join_profile_payload(profile_name: str, description: str,
                              syslog_host: str, syslog_level: str,
                              ntp_server: str, echo_interval: int,
                              tcp_mss: int, led_state: bool) -> str:
    led_elem = "<led-state>true</led-state>" if led_state else "<led-state>false</led-state>"
    return dedent(f"""\
        <config>
          <ap-cfg-data xmlns="{YANG_AP}">
            <ap-profiles>
              <ap-profile>
                <profile-name>{profile_name}</profile-name>
                <description>{description}</description>
                <ap-system-logging>
                  <syslog-host>{syslog_host}</syslog-host>
                  <syslog-level>{syslog_level}</syslog-level>
                </ap-system-logging>
                <ntp-server>{ntp_server}</ntp-server>
                <capwap-timers>
                  <echo-interval>{echo_interval}</echo-interval>
                  <fast-heartbeat-timeout>true</fast-heartbeat-timeout>
                </capwap-timers>
                <tcp-mss-adjust>{tcp_mss}</tcp-mss-adjust>
                {led_elem}
                <telnet>false</telnet>
                <ssh>true</ssh>
              </ap-profile>
            </ap-profiles>
          </ap-cfg-data>
        </config>""")


def run(args: argparse.Namespace, password: str) -> None:
    payload = _ap_join_profile_payload(
        args.profile_name, args.description,
        args.syslog_host, args.syslog_level,
        args.ntp_server, args.echo_interval,
        args.tcp_mss, args.led_state
    )

    if args.dry_run:
        print("── DRY RUN — payload only, no connection ──\n")
        print(payload)
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
        print(f"  Pushing AP join profile '{args.profile_name}' …")
        nc.edit_config(target="running", config=payload)
        print("AP join profile applied successfully.")


def main() -> None:
    p = argparse.ArgumentParser(description="Push AP join profile to Cisco 9800 WLC via NETCONF")
    p.add_argument("--host",           default="",                    help="WLC IP / hostname")
    p.add_argument("--user",           default="admin",               help="NETCONF username")
    p.add_argument("--password",       default="",                    help="Leave blank to prompt")
    p.add_argument("--dry-run",        action="store_true",           help="Print payload without connecting")
    p.add_argument("--profile-name",   default="AP-Join-Standard")
    p.add_argument("--description",    default="Standard AP join profile — NaC managed")
    p.add_argument("--syslog-host",    default="10.0.0.20")
    p.add_argument("--syslog-level",   default="warnings")
    p.add_argument("--ntp-server",     default="10.0.0.30")
    p.add_argument("--echo-interval",  type=int, default=30)
    p.add_argument("--tcp-mss",        type=int, default=1250)
    p.add_argument("--led-state",      action="store_true", default=True)
    p.add_argument("--no-led",         dest="led_state", action="store_false")

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
