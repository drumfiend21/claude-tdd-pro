set -uo pipefail
LOGIN=""; NOW=""; TTL=24
while [[ $# -gt 0 ]]; do
  case "$1" in
    --login) LOGIN="$2"; shift 2 ;;
    --now) NOW="$2"; shift 2 ;;
    --cache-ttl-hours) TTL="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -z "$LOGIN" ]] && { echo "affiliation-lookup: --login required" >&2; exit 2; }
[[ -z "$NOW" ]] && NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

CACHE=".claude-tdd-pro/pr-corpus/affiliation-cache/$LOGIN.json"
if [[ ! -f "$CACHE" ]]; then
  echo "affiliation-lookup: login=$LOGIN cache_status=missing refreshed=true" >&2
  exit 0
fi

CACHE="$CACHE" NOW="$NOW" TTL="$TTL" node -e '
const fs = require("fs");
const c = JSON.parse(fs.readFileSync(process.env.CACHE, "utf8"));
const ageMs = new Date(process.env.NOW).getTime() - new Date(c.fetched_at).getTime();
const ttlMs = parseInt(process.env.TTL, 10) * 3600 * 1000;
const status = ageMs <= ttlMs ? "fresh" : "expired";
const refreshed = status === "expired";
process.stderr.write(`affiliation-lookup: login=${c.login} cache_status=${status} refreshed=${refreshed}\n`);
'
