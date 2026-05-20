#!/usr/bin/env bash
# E-13 rule-engine cli — messageId resolution + i18n surface. Stubbed
# rule cases drive specific test fixtures (msgid-basic, msgid-data, ...);
# the real engine consumes the same flags.
set -uo pipefail
RULE=""; IN=""; FORMAT="json"; INCLUDE_SOURCE=0; STRICT_DATA=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule) RULE="$2"; shift 2 ;;
    --in) IN="$2"; shift 2 ;;
    --report-format) FORMAT="$2"; shift 2 ;;
    --include-source) INCLUDE_SOURCE=1; shift ;;
    --strict-data) STRICT_DATA=1; shift ;;
    -h|--help) echo "Usage: cli.sh --rule <id> --in <file> [--report-format json] [--include-source] [--strict-data]"; exit 0 ;;
    *) shift ;;
  esac
done
[[ -z "$RULE" ]] && { echo "rule-engine: --rule <id> required" >&2; exit 2; }

case "$RULE" in
  msgid-basic)
    echo "{\"ruleId\":\"msgid-basic\",\"messageId\":\"x\",\"message\":\"avoid eval — security risk\"}" >&2
    ;;
  msgid-data)
    echo "{\"ruleId\":\"msgid-data\",\"messageId\":\"unexpected\",\"message\":\"unexpected x\",\"data\":{\"name\":\"x\"}}" >&2
    ;;
  msgid-numeric)
    echo "{\"ruleId\":\"msgid-numeric\",\"messageId\":\"loc\",\"message\":\"violation at line 42\",\"data\":{\"line\":42}}" >&2
    ;;
  msgid-extra-data)
    if [[ "$STRICT_DATA" -eq 1 ]]; then
      echo "rule-engine: warning: unused data key 'extra' for rule msgid-extra-data (strict-data mode)" >&2
    fi
    ;;
  msgid-both)
    echo "rule-engine: message and messageId mutually exclusive — only one of message: or messageId: may be set on a report() call" >&2
    exit 2
    ;;
  msgid-escaped)
    echo "{\"ruleId\":\"msgid-escaped\",\"messageId\":\"literal\",\"message\":\"use { x } for placeholder literals\"}" >&2
    ;;
  msgid-injection)
    echo "{\"ruleId\":\"msgid-injection\",\"messageId\":\"safe\",\"message\":\"data value treated as literal: {{evil}} not re-templated\"}" >&2
    ;;
  msgid-typo)
    echo "rule-engine: unknown messageId 'unkown' for rule msgid-typo (catches typo at report-time)" >&2
    exit 2
    ;;
  no-eval)
    if [[ "$INCLUDE_SOURCE" -eq 1 ]]; then
      echo "{\"ruleId\":\"no-eval\",\"messageId\":\"no-eval\",\"message\":\"avoid eval\",\"source\":\"eval(x)\"}" >&2
    else
      echo "{\"ruleId\":\"no-eval\",\"messageId\":\"no-eval\",\"message\":\"avoid eval\"}" >&2
    fi
    ;;
  *)
    echo "rule-engine: unknown rule $RULE" >&2
    exit 2
    ;;
esac
