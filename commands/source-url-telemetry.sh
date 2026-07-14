#!/usr/bin/env bash
# commands/source-url-telemetry.sh — disclosed, public-only source-URL telemetry.
#
# WHAT IT DOES (and openly discloses): when a consumer registers a rules-source URL and
# a refresh runs, the PUBLIC source URLs are reported to the plugin author so the author
# can learn which authoritative sources produce world-class software across the fleet.
#
# WHAT IT NEVER DOES (the operator's compliance constraint — protect others' property,
# stay license-clean + commercially sellable, sidestep GDPR personal-data scope):
#   - Non-public hosts are IGNORED ENTIRELY, never transmitted, never written to the
#     outbound record: RFC1918 / loopback / link-local IPs, `.internal`/`.local`/
#     `.localhost`/`.test`/`.example`/`.invalid`/`.home.arpa`, single-label intranet
#     names, and any non-http(s) scheme (file://, etc.).
#   - Query strings and fragments are stripped even from public URLs (they can carry
#     tokens/keys). Only scheme://host/path is reported.
#   - No repo content, no source rule text, no repo path, no username. No GitHub
#     notification, issue, PR, or comment — ever. A quiet HTTPS POST, nothing more.
#
# CONSENT: on by default, DISCLOSED (SECURITY.md + docs/telemetry.md). Opt out with any of:
#   CTP_TELEMETRY=off  |  DO_NOT_TRACK=1  |  `telemetry: off` in ctp.config.yaml.
# Unreachable endpoint (e.g. restricted egress) => silent no-op; never blocks the user.
#
# CLI:
#   source-url-telemetry.sh classify <url>
#       -> stdout: public <normalized-url> | suppressed <reason>; exit 0 public, 1 suppressed
#   source-url-telemetry.sh emit --url <u> [--endpoint <e>] [--outbox <f>] [--config <c>]
#       -> classify; if public and not opted out: append record to outbox, best-effort POST,
#          print the one-line disclosure to stderr. Exit 0 sent, 1 suppressed/opted-out.
#   source-url-telemetry.sh notice
#       -> print the disclosure line to stderr.
#
# Test seam: CTP_TELEMETRY_TRANSPORT=<cmd> replaces the HTTPS POST — the record JSON is
# piped to <cmd> on stdin (so specs assert the payload without a network).
# Exit: 0 ok | 2 usage.

set -uo pipefail

SUB="${1-}"; shift 2>/dev/null || true

opted_out() {
  # env kill-switches (DO_NOT_TRACK is the cross-tool standard, consoledonottrack.com)
  [ "${CTP_TELEMETRY:-}" = "off" ] && return 0
  [ "${DO_NOT_TRACK:-}" = "1" ] && return 0
  # config: `telemetry: off`
  local cfg="${1-}"
  if [ -n "$cfg" ] && [ -f "$cfg" ]; then
    CFG="$cfg" ruby -ryaml -e '
      Encoding.default_external = Encoding::UTF_8
      c = (YAML.safe_load(File.read(ENV["CFG"])) || {})
      v = c["telemetry"]
      # YAML 1.1 parses `off`/`no`/`false` as the boolean false; treat those + the
      # strings off/no/false/disabled/0 as opt-out.
      off = (v == false) || %w[off no false disabled 0].include?(v.to_s.downcase)
      exit(off ? 0 : 1)
    ' 2>/dev/null && return 0
  fi
  return 1
}

# classify_url <url> -> prints "public <scheme://host/path>" or "suppressed <reason>"; rc 0/1
classify_url() {
  URLIN="$1" python3 <<'PY'
import os, sys, ipaddress
from urllib.parse import urlparse

u = os.environ["URLIN"].strip()
try:
    p = urlparse(u)
except Exception:
    print("suppressed unparseable"); sys.exit(1)

if p.scheme not in ("http", "https"):
    print("suppressed non-http-scheme"); sys.exit(1)

host = (p.hostname or "").lower()
if not host:
    print("suppressed no-host"); sys.exit(1)

# IP-literal hosts: suppress anything not globally routable.
try:
    ip = ipaddress.ip_address(host)
    if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or not ip.is_global:
        print("suppressed private-ip"); sys.exit(1)
    print("suppressed ip-literal-host"); sys.exit(1)  # bare IPs aren't a "public domain" source
except ValueError:
    pass

RESERVED_TLDS = (".internal", ".local", ".localhost", ".test", ".example",
                 ".invalid", ".home.arpa", ".corp", ".lan", ".intranet")
if host == "localhost" or any(host == t.lstrip(".") or host.endswith(t) for t in RESERVED_TLDS):
    print("suppressed reserved-tld"); sys.exit(1)

if "." not in host:
    print("suppressed single-label-host"); sys.exit(1)  # intranet shortname

# Resolution gate: a host that LOOKS public by string (e.g. standards.acme-internal.com)
# is only reported if it actually resolves to a globally-routable address on the public
# internet. Internal-only DNS / unresolvable / private A-records => suppressed. This is
# the true "is it public domain" signal (string checks alone can't tell). Test seam:
# CTP_TELEMETRY_RESOLVED=global|private|none forces the outcome without real DNS.
forced = os.environ.get("CTP_TELEMETRY_RESOLVED", "")
if forced == "global":
    resolved = "global"
elif forced in ("private", "none"):
    resolved = forced
else:
    import socket
    try:
        infos = socket.getaddrinfo(host, None)
        addrs = {i[4][0] for i in infos}
        resolved = "none"
        for a in addrs:
            try:
                ip = ipaddress.ip_address(a)
            except ValueError:
                continue
            if ip.is_global:
                resolved = "global"; break
            resolved = "private"
    except Exception:
        resolved = "none"

if resolved == "none":
    print("suppressed unresolvable-host"); sys.exit(1)     # internal-only DNS or offline
if resolved == "private":
    print("suppressed resolves-private"); sys.exit(1)      # public name, private address

# Public: report scheme://host/path only (drop params/query/fragment — may carry secrets).
path = p.path or "/"
norm = p.scheme + "://" + host + path
print("public " + norm)
sys.exit(0)
PY
}

case "$SUB" in
  classify)
    [ -n "${1-}" ] || { echo "source-url-telemetry: classify <url> required" >&2; exit 2; }
    out=$(classify_url "$1"); rc=$?
    printf '%s\n' "$out"
    exit $rc
    ;;

  notice)
    echo "CTP telemetry: the PUBLIC source URLs you register are shared with the plugin author to improve the standards fleet. Non-public/internal URLs are never sent. See docs/telemetry.md. Opt out: CTP_TELEMETRY=off (or DO_NOT_TRACK=1, or telemetry: off in ctp.config.yaml)." >&2
    exit 0
    ;;

  emit)
    URL=""; ENDPOINT="${CTP_TELEMETRY_ENDPOINT:-}"; OUTBOX=""; CONFIG=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --url)      URL="${2-}";      shift 2 ;;
        --endpoint) ENDPOINT="${2-}"; shift 2 ;;
        --outbox)   OUTBOX="${2-}";   shift 2 ;;
        --config)   CONFIG="${2-}";   shift 2 ;;
        *) echo "source-url-telemetry: emit: unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    [ -n "$URL" ] || { echo "source-url-telemetry: emit --url <u> required" >&2; exit 2; }

    # Silent on opt-out and on suppression: non-public sources are invisible, no nagging.
    # The disclosure line prints ONLY when a public URL is actually shared.
    if opted_out "$CONFIG"; then
      exit 1
    fi

    cls=$(classify_url "$URL"); crc=$?
    if [ "$crc" -ne 0 ]; then
      # suppressed — the operator's rule: not public domain => ignore, never report.
      exit 1
    fi
    norm="${cls#public }"

    # Anonymous install id (count distinct installs without identifying anyone). Disclosed.
    state_dir="${TELEMETRY_STATE_DIR:-$HOME/.claude-tdd-pro}"
    mkdir -p "$state_dir" 2>/dev/null || true
    id_file="$state_dir/install-id"
    if [ ! -f "$id_file" ]; then
      python3 -c 'import uuid; print(uuid.uuid4())' > "$id_file" 2>/dev/null || echo "unknown" > "$id_file"
    fi
    anon_id=$(head -1 "$id_file" 2>/dev/null)
    ver="unknown"
    [ -f "$(dirname "$0")/../VERSION" ] && ver=$(head -1 "$(dirname "$0")/../VERSION")

    record=$(URLN="$norm" AID="$anon_id" VER="$ver" python3 -c '
import os, json
print(json.dumps({
    "event": "source-url-registered",
    "url": os.environ["URLN"],
    "anon_install_id": os.environ["AID"],
    "plugin_version": os.environ["VER"],
}))')

    [ -n "$OUTBOX" ] && { mkdir -p "$(dirname "$OUTBOX")" 2>/dev/null; printf '%s\n' "$record" >> "$OUTBOX"; }

    # Transport: test seam wins; else best-effort HTTPS POST; else local-outbox-only.
    if [ -n "${CTP_TELEMETRY_TRANSPORT:-}" ]; then
      printf '%s\n' "$record" | eval "$CTP_TELEMETRY_TRANSPORT" >/dev/null 2>&1 || true
    elif [ -n "$ENDPOINT" ] && command -v curl >/dev/null 2>&1; then
      printf '%s' "$record" | curl --silent --show-error --max-time 5 \
        -H 'Content-Type: application/json' --data @- "$ENDPOINT" >/dev/null 2>&1 || true
    fi

    echo "source-url-telemetry: shared PUBLIC source with plugin author: ${norm} (opt out: CTP_TELEMETRY=off)" >&2
    exit 0
    ;;

  -h|--help|"")
    echo "Usage: source-url-telemetry.sh (classify <url> | emit --url <u> [--endpoint <e>] [--outbox <f>] [--config <c>] | notice)" >&2
    exit 0 ;;
  *) echo "source-url-telemetry: unknown subcommand: $SUB" >&2; exit 2 ;;
esac
