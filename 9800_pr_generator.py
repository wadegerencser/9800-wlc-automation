# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) 2026 Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""
9800 WLC Daily PR Generator

What it does:
  1. Picks 2 unfinished 9800 automation topics from a list of 50.
  2. Uses Claude to write a production-ready Ansible playbook for each.
  3. Commits both files to a new branch in the target GitHub repo.
  4. Opens one pull request.

Run once per day. Each PR counts as multiple GitHub contribution credits
(commit + PR creation + merge).

Prerequisites:
  pip install anthropic
  export ANTHROPIC_API_KEY=sk-ant-...
  gh auth login          # GitHub CLI, must be authenticated
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

try:
    import anthropic
except ImportError:
    sys.exit("Missing dependency — run: pip install anthropic")

try:
    from twilio.rest import Client as TwilioClient
    _TWILIO_AVAILABLE = True
except ImportError:
    _TWILIO_AVAILABLE = False

# ─── CONFIG ──────────────────────────────────────────────────────────────────
REPO         = "mgerencs/sac-mgerencs-9800-wlc-automation"
GH_HOST      = "wwwin-github.cisco.com"              # Cisco internal GHE
BASE_BRANCH  = "main"
FILES_PER_PR = 2
STATE_FILE   = Path.home() / ".9800_pr_state.json"
MODEL        = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-5")
# ─────────────────────────────────────────────────────────────────────────────

# (slug, task description passed to Claude)
# Slug → filename; description → what Claude writes the playbook for.
TOPICS = [
    ("ssid_wlan_profile",           "Create a WLAN/SSID profile on the 9800 with WPA3-Enterprise security, QoS markings, and VLAN assignment"),
    ("radio_profile_11ax_5ghz",     "Configure an 802.11ax (Wi-Fi 6) radio profile for the 5 GHz band with optimised MCS, spatial streams, and OFDMA settings"),
    ("radio_profile_11ax_24ghz",    "Configure an 802.11ax radio profile for the 2.4 GHz band with legacy CCK rates disabled"),
    ("rf_profile_high_density",     "Create an RF profile tuned for high-density deployments: reduced Tx power, tight RSSI thresholds, and RRM settings"),
    ("rf_profile_wide_coverage",    "Create an RF profile for wide-area coverage: higher Tx power, extended thresholds, no band steering"),
    ("ap_join_profile",             "Define an AP join profile with CAPWAP timer settings, country code, and DNS controller discovery"),
    ("flex_profile_branch",         "FlexConnect profile for a remote branch office: local VLAN mappings, local auth fallback, and split tunnelling"),
    ("site_tag_campus",             "Create a campus site tag linking an AP join profile and flex profile together"),
    ("policy_tag",                  "Create a policy tag that maps a WLAN to a policy profile"),
    ("rf_tag",                      "Create an RF tag combining separate 2.4 GHz and 5 GHz radio profiles"),
    ("tag_apply_ap_filter",         "Apply site, policy, and RF tags to a group of APs using a name filter"),
    ("ha_sso_pair",                 "Configure HA SSO between primary and standby 9800: priorities, pre-emption, peer IP, and keep-alive timers"),
    ("aaa_radius_server",           "Add a RADIUS authentication and accounting server with deadtime, timeout, and retry settings"),
    ("aaa_server_group",            "Create a RADIUS server group and bind it to AAA method lists for 802.1X dot1x"),
    ("dot1x_auth_profile",          "Configure a dot1x authentication profile with EAP-TLS, RADIUS CoA, and session timeout"),
    ("guest_wlan_webauth",          "Configure a guest WLAN with central WebAuth redirect and pre-auth ACL"),
    ("guest_wlan_anchor",           "Configure guest mobility anchor/foreign setup between two 9800 controllers on separate VLANs"),
    ("wlan_policy_profile",         "Create a WLAN policy profile: central switching, VLAN, DHCP required, and exclusion timer"),
    ("qos_marking_per_wlan",        "Configure DSCP ingress/egress QoS markings for a WLAN to support voice and video traffic"),
    ("rogue_detection_containment", "Configure rogue AP detection classification rules and manual containment response"),
    ("cleanair_both_bands",         "Enable CleanAir on 2.4 GHz and 5 GHz with alarm thresholds and interference reporting"),
    ("mdns_service_policy",         "Configure mDNS service policy to proxy Apple Bonjour and Chromecast across WLANs and VLANs"),
    ("pnp_ap_onboarding",           "Configure a PnP AP onboarding profile with controller IP, management VLAN, and image pre-download"),
    ("software_install_activate",   "Automate IOS-XE software install, activate, and commit on the 9800 using the install mode CLI"),
    ("netconf_create_wlan",         "Use ncclient (NETCONF) to create and commit a WLAN on the 9800 via the Cisco-IOS-XE-wireless YANG model"),
    ("restconf_ap_inventory",       "Use RESTCONF (Python requests) to GET the full AP inventory from the 9800 operational datastore"),
    ("restconf_patch_rf_profile",   "Use RESTCONF PATCH to update a single RF profile parameter without a full replace"),
    ("band_steering_11v",           "Configure 802.11v BSS Transition and load balancing to steer dual-band clients to 5 GHz"),
    ("client_load_balancing",       "Set per-radio client limits and enable AP load balancing within a site"),
    ("ewc_mode_conversion",         "Convert an AP from CAPWAP to Embedded Wireless Controller (EWC) mode and validate operation"),
    ("mobility_group_peers",        "Configure a mobility group with peer controller entries for seamless inter-controller L3 roaming"),
    ("dtls_data_encryption",        "Enable DTLS encryption for AP CAPWAP data traffic on the 9800"),
    ("client_acl_ipv4",             "Apply a named IPv4 ACL to a WLAN policy profile to restrict wireless client traffic"),
    ("umbrella_dns_integration",    "Integrate Cisco Umbrella DNS security into a WLAN via the 9800 parameter map and DNS snooping"),
    ("client_exclusion_policy",     "Configure client exclusion: max authentication failures, exclusion timeout, and SNMP trap on exclusion"),
    ("wpa3_enterprise_192bit",      "Configure WPA3-Enterprise 192-bit mode (CNSA suite) on a high-security WLAN"),
    ("pmf_802_11w_required",        "Set Protected Management Frames (802.11w) to Required and tune association comeback and SA query timers"),
    ("ft_11r_over_ds",              "Configure 802.11r Fast Transition over-the-DS for voice and real-time roaming"),
    ("okc_key_caching",             "Enable Opportunistic Key Caching on the 9800 for fast reassociation without a full 802.1X exchange"),
    ("ipsk_iot_segmentation",       "Configure Identity PSK profiles to place IoT devices on isolated VLANs without requiring 802.1X"),
    ("sae_wpa3_personal",           "Configure WPA3-Personal with SAE and Hash-to-Element on a consumer or SMB WLAN"),
    ("ap_lsc_cert_provisioning",    "Configure Locally Significant Certificate provisioning for AP authentication to the 9800"),
    ("syslog_streaming_siem",       "Configure syslog host, severity filter, and facility to forward 9800 events to an external SIEM"),
    ("snmpv3_nms_polling",          "Configure an SNMPv3 user with authPriv for secure NMS polling and trap destination"),
    ("grpc_mdt_subscription",       "Configure a gRPC model-driven telemetry subscription streaming AP and client KPIs to a collector"),
    ("yang_client_state_query",     "Query 9800 wireless client operational state using ncclient with the IOS-XE wireless YANG model"),
    ("day0_base_config",            "Day-0 base configuration playbook for a fresh 9800 deployment: hostname, NTP, AAA, management VLAN, and SSH hardening"),
    ("ap_group_to_tag_migration",   "Migrate a legacy AP-group configuration to the 9800 tag-based model (site, policy, and RF tags)"),
    ("multicast_direct_video",      "Configure multicast-direct on a WLAN to support video surveillance or high-rate multicast streams"),
    ("passive_client_arp_proxy",    "Enable passive client mode and ARP proxy to reduce broadcast overhead on large WLANs"),
]

FILE_HEADER = """\
# =============================================================================
# Cisco CX US Public Sector Automation Hub
# Repository : sac-mgerencs-9800-wlc-automation
# Author     : Wade Gerencser (mgerencs) · CX US Public Sector
# Copyright  : (c) {year} Cisco and/or its affiliates.
# License    : MIT — see LICENSE
# =============================================================================
"""

PROMPT = """\
Write a production-ready Ansible playbook (YAML) for the following task on a \
Cisco Catalyst 9800 Wireless LAN Controller running IOS-XE: {desc}.

Requirements:
- Use cisco.iosxe or cisco.ios collection modules where a purpose-built module \
exists. Fall back to ansible.netcommon.cli_config or cisco.ios.ios_config for \
anything else.
- Include a `vars:` block with realistic placeholder values (e.g. \
controller_ip, radius_server_ip, ssid_name).
- Use descriptive task names written as actions ("Configure RADIUS server").
- All IOS-XE CLI must be real and runnable against a 9800.
- Return ONLY valid YAML starting with `---`. No markdown fences, no prose.
"""


def load_state() -> dict:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"completed": [], "pr_count": 0}


def save_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2))


def next_topics(state: dict) -> list[tuple[str, str]]:
    done = set(state["completed"])
    remaining = [t for t in TOPICS if t[0] not in done]
    if not remaining:
        print("All topics exhausted — resetting cycle.")
        state["completed"] = []
        save_state(state)
        remaining = list(TOPICS)
    return remaining[:FILES_PER_PR]


def generate_playbook(slug: str, desc: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN")
    base_url = os.environ.get("ANTHROPIC_BASE_URL")
    client = anthropic.Anthropic(api_key=api_key, **({"base_url": base_url} if base_url else {}))
    response = client.messages.create(
        model=MODEL,
        max_tokens=2048,
        messages=[{"role": "user", "content": PROMPT.format(desc=desc)}],
    )
    body = next(b.text for b in response.content if b.type == "text").strip()
    if body.startswith("```"):
        lines = body.split("\n")
        body = "\n".join(lines[1:])
    if body.rstrip().endswith("```"):
        body = body.rstrip()[:-3].rstrip()
    header = FILE_HEADER.format(year=date.today().year)
    if body.startswith("---"):
        return header + body
    return header + "---\n" + body


def run_cmd(cmd: list[str], cwd: str | None = None, extra_env: dict | None = None) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True, env=env)


def gh(*args, cwd=None) -> subprocess.CompletedProcess:
    return run_cmd(["gh"] + list(args), cwd=cwd, extra_env={"GH_HOST": GH_HOST})


def create_pr(topics_and_playbooks: list[tuple[tuple, str]]) -> str:
    today = date.today().isoformat()
    slugs = "_and_".join(t[0] for t, _ in topics_and_playbooks)
    branch = f"9800/{today}/{slugs}"

    tmpdir = tempfile.mkdtemp(prefix="9800_pr_")
    try:
        print(f"  Cloning {REPO} from {GH_HOST}...")
        gh("repo", "clone", REPO, tmpdir)
        run_cmd(["git", "checkout", BASE_BRANCH], cwd=tmpdir)
        run_cmd(["git", "checkout", "-b", branch], cwd=tmpdir)

        playbooks_dir = Path(tmpdir) / "playbooks"
        playbooks_dir.mkdir(exist_ok=True)

        file_lines = []
        for (slug, desc), content in topics_and_playbooks:
            filename = f"{slug}.yml"
            (playbooks_dir / filename).write_text(content)
            run_cmd(["git", "add", f"playbooks/{filename}"], cwd=tmpdir)
            file_lines.append(f"- `playbooks/{filename}` — {desc}")
            print(f"    + playbooks/{filename}")

        commit_msg = "9800: " + ", ".join(t[0] for t, _ in topics_and_playbooks)
        run_cmd(["git", "commit", "-m", commit_msg], cwd=tmpdir)
        run_cmd(["git", "push", "origin", branch], cwd=tmpdir)     # contribution 1: push

        pr_body = (
            "Auto-generated Cisco 9800 WLC Ansible automation playbooks.\n\n"
            "## Files\n"
            + "\n".join(file_lines)
            + "\n\n_Generated with Claude. Part of CX US Public Sector 9800 automation series._"
        )
        result = gh(                                                # contribution 2: PR open
            "pr", "create",
            "--title", f"9800 automation – {today}",
            "--body", pr_body,
            "--base", BASE_BRANCH,
            "--head", branch,
            cwd=tmpdir
        )
        pr_url = result.stdout.strip()

        gh("pr", "merge", pr_url, "--merge", "--delete-branch",   # contribution 3: PR merge
           cwd=tmpdir)
        print(f"  Merged.")
        return pr_url

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def send_sms(message: str) -> None:
    if not _TWILIO_AVAILABLE:
        return
    sid   = os.environ.get("TWILIO_ACCOUNT_SID")
    token = os.environ.get("TWILIO_AUTH_TOKEN")
    from_ = os.environ.get("TWILIO_FROM_NUMBER")
    to    = os.environ.get("TWILIO_TO_NUMBER")
    if not all([sid, token, from_, to]):
        return
    try:
        TwilioClient(sid, token).messages.create(body=message, from_=from_, to=to)
        print("  SMS sent.")
    except Exception as e:
        print(f"  SMS failed: {e}")


def main() -> None:
    if not (os.getenv("ANTHROPIC_API_KEY") or os.getenv("ANTHROPIC_AUTH_TOKEN")):
        sys.exit("Set ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN before running.")

    state = load_state()
    selected = next_topics(state)
    print(f"Generating: {[t[0] for t in selected]}")

    topics_and_playbooks = []
    for slug, desc in selected:
        print(f"  {slug}...")
        content = generate_playbook(slug, desc)
        topics_and_playbooks.append(((slug, desc), content))

    pr_url = create_pr(topics_and_playbooks)

    state["completed"].extend(t[0] for t in selected)
    state["pr_count"] += 1
    save_state(state)

    remaining = len(TOPICS) - len(state["completed"])
    print(f"\nPR #{state['pr_count']} merged: {pr_url}")
    print(f"Topics remaining this cycle: {remaining}/{len(TOPICS)}")

    send_sms(
        f"9800 PR #{state['pr_count']} merged ✓ "
        f"Topics: {', '.join(t[0] for t in selected)}. "
        f"{remaining} topics left this cycle."
    )


if __name__ == "__main__":
    main()
