# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
STIG Hardening via NETCONF – Cisco Catalyst 9800 WLC (IOS-XE)

Pushes STIG-aligned hardening configuration to a 9800 controller using
NETCONF edit-config and the Cisco-IOS-XE YANG models.

Maps to: DISA IOS-XE Router NDM STIG → NIST SP 800-53 Rev 5

Requires: pip install ncclient

── Platform Install ──────────────────────────────────────────────────────────

  macOS / Linux
    pip install ncclient
    python3 netconf/stig_harden_9800.py --host 192.168.1.1 --user admin

  Windows (PowerShell or Command Prompt — native Python, no WSL needed)
    pip install ncclient
    python netconf\\stig_harden_9800.py --host 192.168.1.1 --user admin

  NOTE: Omit --password to be prompted securely.
        Use --dry-run to print the NETCONF payloads without connecting.

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

YANG_NATIVE   = "http://cisco.com/ns/yang/Cisco-IOS-XE-native"
YANG_AAA      = "http://cisco.com/ns/yang/Cisco-IOS-XE-aaa"
YANG_LOGGING  = "http://cisco.com/ns/yang/Cisco-IOS-XE-logging"
YANG_NTP      = "http://cisco.com/ns/yang/Cisco-IOS-XE-ntp"
YANG_SNMP     = "http://cisco.com/ns/yang/Cisco-IOS-XE-snmp"


# ── YANG payloads ─────────────────────────────────────────────────────────────

def _ssh_payload(version: int, timeout: int, retries: int) -> str:
    # STIG: V-220151, V-220152 | NIST: SC-8, SC-10
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <ip>
              <ssh>
                <version>{version}</version>
                <time-out>{timeout}</time-out>
                <authentication-retries>{retries}</authentication-retries>
              </ssh>
            </ip>
          </native>
        </config>""")


def _banner_payload(banner_text: str) -> str:
    # STIG: V-220142 | NIST: AC-8
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <banner>
              <login>
                <banner>{banner_text}</banner>
              </login>
            </banner>
          </native>
        </config>""")


def _aaa_payload(tacacs_name: str, tacacs_ip: str, tacacs_port: int,
                 tacacs_key: str, authen_list: str, author_list: str,
                 acct_list: str) -> str:
    # STIG: V-220143, V-220144, V-220145 | NIST: IA-2, AC-3, AU-12
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <tacacs>
              <server>
                <name>{tacacs_name}</name>
                <address>
                  <ipv4>{tacacs_ip}</ipv4>
                </address>
                <key>
                  <encryption>0</encryption>
                  <key>{tacacs_key}</key>
                </key>
              </server>
            </tacacs>
            <aaa xmlns="{YANG_AAA}">
              <new-model/>
              <authentication>
                <login>
                  <name>{authen_list}</name>
                  <a1><group><name>tacacs+</name></group></a1>
                  <a2><local/></a2>
                </login>
              </authentication>
              <authorization>
                <exec>
                  <name>{author_list}</name>
                  <a1><group><name>tacacs+</name></group></a1>
                  <a2><local/></a2>
                </exec>
              </authorization>
              <accounting>
                <exec>
                  <name>{acct_list}</name>
                  <start-stop>
                    <group><name>tacacs+</name></group>
                  </start-stop>
                </exec>
              </accounting>
            </aaa>
          </native>
        </config>""")


def _logging_payload(syslog_ip: str, source_intf: str, severity: str) -> str:
    # STIG: V-220146 | NIST: AU-2, AU-9
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <logging>
              <host>
                <ipv4-host-list>
                  <ipv4-host>{syslog_ip}</ipv4-host>
                </ipv4-host-list>
              </host>
              <source-interface>
                <interface-name>{source_intf}</interface-name>
              </source-interface>
              <trap>
                <severity>{severity}</severity>
              </trap>
            </logging>
          </native>
        </config>""")


def _ntp_payload(primary: str, secondary: str, key_id: int,
                 key_val: str, source_intf: str) -> str:
    # STIG: V-220147 | NIST: AU-8
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <ntp>
              <authenticate/>
              <authentication-key>
                <number>{key_id}</number>
                <md5>
                  <encryption>0</encryption>
                  <value>{key_val}</value>
                </md5>
              </authentication-key>
              <trusted-key>
                <key-number>{key_id}</key-number>
              </trusted-key>
              <source>
                <source-interface>{source_intf}</source-interface>
              </source>
              <server>
                <server-list>
                  <ip-address>{primary}</ip-address>
                  <prefer/>
                </server-list>
                <server-list>
                  <ip-address>{secondary}</ip-address>
                </server-list>
              </server>
            </ntp>
          </native>
        </config>""")


def _snmp_payload(group: str, user: str, auth_proto: str, auth_pass: str,
                  priv_proto: str, priv_pass: str,
                  contact: str, location: str) -> str:
    # STIG: V-220148 | NIST: SC-8, IA-2 — remove v1/v2c, enforce v3 authPriv
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <snmp-server>
              <contact>{contact}</contact>
              <location>{location}</location>
              <group>
                <id>{group}</id>
                <v3>
                  <priv/>
                </v3>
              </group>
              <user>
                <name>{user}</name>
                <grpname>{group}</grpname>
                <v3>
                  <auth>
                    <algorithm>{auth_proto}</algorithm>
                    <password>{auth_pass}</password>
                  </auth>
                  <priv>
                    <algorithm>{priv_proto.split()[0]}</algorithm>
                    <password>{priv_pass}</password>
                  </priv>
                </v3>
              </user>
            </snmp-server>
          </native>
        </config>""")


def _services_payload() -> str:
    # STIG: V-220149, V-220155 | NIST: CM-7
    return dedent(f"""\
        <config>
          <native xmlns="{YANG_NATIVE}">
            <ip>
              <source-route>false</source-route>
              <http>
                <server>false</server>
              </http>
            </ip>
            <service>
              <password-encryption/>
            </service>
          </native>
        </config>""")


# ── Main ──────────────────────────────────────────────────────────────────────

STEPS = [
    ("SSH hardening",          lambda a: _ssh_payload(2, 60, 3)),
    ("DoD login banner",       lambda a: _banner_payload(
        "You are accessing a U.S. Government Information System. "
        "Unauthorized use is prohibited and subject to criminal and civil penalties."
    )),
    ("AAA / TACACS+",          lambda a: _aaa_payload(
        a.tacacs_name, a.tacacs_ip, a.tacacs_port, a.tacacs_key,
        "AAA-AUTHEN", "AAA-AUTHOR", "AAA-ACCT"
    )),
    ("Syslog",                 lambda a: _logging_payload(a.syslog_ip, a.source_intf, "informational")),
    ("NTP",                    lambda a: _ntp_payload(
        a.ntp_primary, a.ntp_secondary, a.ntp_key_id, a.ntp_key_val, a.source_intf
    )),
    ("SNMPv3",                 lambda a: _snmp_payload(
        "SNMP-V3-RO", "snmpv3user", "sha", a.snmp_auth_pass,
        "aes", a.snmp_priv_pass, a.snmp_contact, a.snmp_location
    )),
    ("Disable unused services", lambda a: _services_payload()),
]


def run(args: argparse.Namespace, password: str) -> None:
    if args.dry_run:
        print("── DRY RUN — payloads only, no connection ──")
        for label, builder in STEPS:
            print(f"\n{'─'*60}\n# {label}\n{'─'*60}")
            print(builder(args))
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
        for label, builder in STEPS:
            print(f"  Applying: {label} …")
            nc.edit_config(target="running", config=builder(args))
        print("\nSTIG hardening complete.")


def main() -> None:
    p = argparse.ArgumentParser(description="Push STIG hardening to Cisco 9800 WLC via NETCONF")
    p.add_argument("--host",          default="",         help="WLC IP / hostname")
    p.add_argument("--user",          default="admin",    help="NETCONF username")
    p.add_argument("--password",      default="",         help="Leave blank to prompt")
    p.add_argument("--dry-run",       action="store_true",help="Print payloads without connecting")
    p.add_argument("--tacacs-name",   default="TACACS-PRIMARY")
    p.add_argument("--tacacs-ip",     default="10.0.0.10")
    p.add_argument("--tacacs-port",   type=int, default=49)
    p.add_argument("--tacacs-key",    default="CHANGEME_TACACS")
    p.add_argument("--syslog-ip",     default="10.0.0.20")
    p.add_argument("--source-intf",   default="Loopback0")
    p.add_argument("--ntp-primary",   default="10.0.0.30")
    p.add_argument("--ntp-secondary", default="10.0.0.31")
    p.add_argument("--ntp-key-id",    type=int, default=1)
    p.add_argument("--ntp-key-val",   default="CHANGEME_NTP")
    p.add_argument("--snmp-auth-pass",default="CHANGEME_AUTH")
    p.add_argument("--snmp-priv-pass",default="CHANGEME_PRIV")
    p.add_argument("--snmp-contact",  default="noc@example.gov")
    p.add_argument("--snmp-location", default="DC1-RACK-A1")

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
