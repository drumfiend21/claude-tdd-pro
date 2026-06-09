#!/usr/bin/env bash
# lib/fetch-frequency-grammar.sh — §2.28 fetch_frequency cadence grammar.
#
# Single source of truth for the configurable-frequency cadence grammar,
# shared by standards/poll-scheduler.sh (S-20) and
# standards/validate-fetch-frequency.sh (§2.28 contract) so the grammar is
# defined once and cannot drift between the scheduler and the validator.
#
# Per §2.28: a fetch_frequency accepts EITHER a calendar token
# (daily|weekly|monthly|quarterly|on-demand) OR a sub-day interval matching
# ^[0-9]+(ms|s|m|h)$ OR the shorthand any-frequency. Default when unset is
# daily. §27.5 grammar floor is 1ms (a zero interval is rejected).
#
# ff_resolve_cadence <cadence>
#   On a valid cadence: echoes "<interval_ms> <resolved_token> <class>" and
#   returns 0. class is one of: calendar | subday | manual | any-frequency.
#   An unset/empty cadence resolves to the daily default.
#   On an invalid cadence: emits nothing and returns 2.

ff_resolve_cadence() {
  c="$1"
  case "$c" in
    ""|daily)      echo "86400000 daily calendar" ;;
    weekly)        echo "604800000 weekly calendar" ;;
    monthly)       echo "2592000000 monthly calendar" ;;
    quarterly)     echo "7776000000 quarterly calendar" ;;
    on-demand)     echo "-1 on-demand manual" ;;
    any-frequency) echo "-1 any-frequency any-frequency" ;;
    *)
      # §2.28 sub-day interval grammar: ^[0-9]+(ms|s|m|h)$
      if printf '%s' "$c" | grep -Eq '^[0-9]+(ms|s|m|h)$'; then
        num=$(printf '%s' "$c" | sed -E 's/(ms|s|m|h)$//')
        unit=$(printf '%s' "$c" | sed -E 's/^[0-9]+//')
        # §27.5 grammar floor is 1ms; reject a zero interval.
        if [ "$num" -eq 0 ] 2>/dev/null; then return 2; fi
        case "$unit" in
          ms) ms="$num" ;;
          s)  ms=$((num * 1000)) ;;
          m)  ms=$((num * 60000)) ;;
          h)  ms=$((num * 3600000)) ;;
        esac
        echo "$ms $c subday"
      else
        return 2
      fi
      ;;
  esac
}
