# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
Site Tag Automation via NETCONF – Cisco Catalyst 9800 WLC

Creates site tags and binds AP profiles using NETCONF edit-config and
Cisco-IOS-XE-wireless-site-cfg YANG models.

Requires: pip install ncclient pyyaml

── Platform Install ──────────────────────────────────────────────────────────

  macOS / Linux
    pip install ncclient pyyaml
    python3 netconf/site_tag_9800.py --host 192.168.1.1 --user admin \
        --vars vars/site_tag_defaults.yml

  Windows (PowerShell or Command Prompt — native Python, no WSL needed)
    pip install ncclient pyyaml
    python netconf\\site_tag_9800.py --host 192.168.1.1 --user admin ^
        --vars vars\\site_tag_defaults.yml

  Dry-run (print payloads, no connection):
    python3 netconf/site_tag_9800.py --dry-run --vars vars/site_tag_defaults.yml

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
YANG_SITE = "http://cisco.com/ns/yang/Cisco-IOS-XE-wireless-site-cfg"


def _site_tag_payload(tags: list) -> str:
    entries = []
    for tag in tags:
        local_elem = "<local-site/>" if tag.get("local_site") else ""
        flex_elem  = f"<flex-profile>{tag['flex_profile']}</flex-profile>" \
                     if tag.get("flex_profile") else ""
        entries.append(dedent(f"""\
              <site-tag-config>
                <site-tag-name>{tag['name']}</site-tag-name>
                <description>{tag.get('description', '')}</description>
                <ap-profile>{tag['ap_profile']}</ap-profile>
                {local_elem}
                {flex_elem}
              </site-tag-config>"""))

    tags_xml = "\n".join(entries)
    return dedent(f"""\
        <config>
          <site-cfg-data xmlns="{YANG_SITE}">
            <site-tag-configs>
              {tags_xml}
            </site-tag-configs>
          </site-cfg-data>
        </config>""")


def run(args: argparse.Namespace, password: str, tags: list) -> None:
    payload = _site_tag_payload(tags)

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
        print(f"  Pushing {len(tags)} site tag(s) …")
        nc.edit_config(target="running", config=payload)
        for tag in tags:
            print(f"    ✓ {tag['name']}")
        print("Site tags applied successfully.")


def main() -> None:
    p = argparse.ArgumentParser(description="Push site tags to Cisco 9800 WLC via NETCONF")
    p.add_argument("--host",     default="",    help="WLC IP / hostname")
    p.add_argument("--user",     default="admin")
    p.add_argument("--password", default="",    help="Leave blank to prompt")
    p.add_argument("--dry-run",  action="store_true")
    p.add_argument("--vars",     default="vars/site_tag_defaults.yml",
                   help="Path to YAML vars file containing site_tags list")

    args = p.parse_args()
    if not args.dry_run and not args.host:
        p.error("--host is required unless --dry-run is specified")

    with open(args.vars) as f:
        data = yaml.safe_load(f)
    tags = data.get("site_tags", [])
    if not tags:
        print("ERROR: no site_tags found in vars file", file=sys.stderr)
        sys.exit(1)

    password = args.password or (
        getpass.getpass(f"Password for {args.user}@{args.host}: ")
        if not args.dry_run else ""
    )

    try:
        run(args, password, tags)
    except RPCError as exc:
        print(f"NETCONF RPC error: {exc.message}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted.")


if __name__ == "__main__":
    main()
