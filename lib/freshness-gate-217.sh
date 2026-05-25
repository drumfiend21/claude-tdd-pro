#!/usr/bin/env bash
# §2.17 live-freshness-gate handler. Shared by:
#   standards/freshness-gate.sh
#   compliance/freshness-gate.sh
#   pr-corpus/freshness-gate.sh
#
# Sourced when any of the §2.17 CLI flags (--operation) is detected.
# Reads:
#   F217_LAST_FETCH_DIR   directory of <id>.txt last-fetch markers (caller-set)
# Args: all original $@ passed through.

f217_run() {
  local OP="" SRC="" NOW="" WIN="" SKIP=0
  local AUDIT_LOG="" OPERATOR="" PROV_OUT="" EMIT=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --operation)        OP="${2-}";        shift 2 ;;
      --source|--framework) SRC="${2-}";     shift 2 ;;
      --now)              NOW="${2-}";       shift 2 ;;
      --freshness-window) WIN="${2-}";       shift 2 ;;
      --skip-fresh)       SKIP=1;            shift ;;
      --audit-log)        AUDIT_LOG="${2-}"; shift 2 ;;
      --operator)         OPERATOR="${2-}";  shift 2 ;;
      --provenance-out)   PROV_OUT="${2-}";  shift 2 ;;
      --emit)             EMIT="${2-}";      shift 2 ;;
      *)                  shift ;;
    esac
  done

  if [ -z "$OP" ] || [ -z "$SRC" ] || [ -z "$NOW" ] || [ -z "$WIN" ]; then
    echo "freshness-gate: --operation, --source/--framework, --now, --freshness-window required" >&2
    return 2
  fi

  LAST_FETCH_DIR="$F217_LAST_FETCH_DIR" SRC="$SRC" NOW="$NOW" WIN="$WIN" \
  OP="$OP" SKIP="$SKIP" AUDIT_LOG="$AUDIT_LOG" OPERATOR="$OPERATOR" \
  PROV_OUT="$PROV_OUT" EMIT="$EMIT" ruby - <<'RUBY'
    require 'json'
    require 'time'
    last_fetch_dir = ENV['LAST_FETCH_DIR']
    src     = ENV['SRC']
    now_iso = ENV['NOW']
    win     = ENV['WIN']
    skip    = ENV['SKIP'] == '1'
    op      = ENV['OP']
    audit   = ENV['AUDIT_LOG'].to_s
    oper    = ENV['OPERATOR'].to_s
    prov    = ENV['PROV_OUT'].to_s
    emit    = ENV['EMIT'].to_s

    secs = case win
           when /\A(\d+)s\z/  then $1.to_i
           when /\A(\d+)m\z/  then $1.to_i * 60
           when /\A(\d+)h\z/  then $1.to_i * 3600
           when /\A(\d+)d\z/  then $1.to_i * 86400
           when /\A(\d+)w\z/  then $1.to_i * 604800
           when 'hourly'      then 3600
           when 'daily'       then 86400
           when 'weekly'      then 604800
           when 'monthly'     then 30 * 86400
           else
             STDERR.write("freshness-gate: bad --freshness-window: #{win}\n"); exit 2
           end

    fetch_file = File.join(last_fetch_dir, "#{src}.txt")
    unless File.exist?(fetch_file)
      STDERR.write("freshness-gate: no last-fetch record at #{fetch_file}\n")
      exit 1
    end
    last = Time.iso8601(File.read(fetch_file).strip)
    now  = Time.iso8601(now_iso)
    age  = now - last
    fresh = age <= secs

    status = if skip
               'operator-bypass'
             elsif fresh
               'fresh-within-fetch-frequency'
             else
               'stale-warn-degraded'
             end

    if emit == 'fields'
      STDERR.write("source=#{src}\n")
      STDERR.write("operation=#{op}\n")
      STDERR.write("age_seconds=#{age.to_i}\n")
      STDERR.write("freshness_at_generation=#{status}\n")
    end

    if !prov.empty?
      rec = { "source" => src, "operation" => op, "freshness_at_generation" => status, "checked_at" => now_iso }
      File.write(prov, JSON.generate(rec))
    end

    if !audit.empty? && skip
      File.open(audit, 'a') { |f|
        f.write(JSON.generate({
          "event"     => "skip-fresh-bypass",
          "operator"  => oper,
          "source"    => src,
          "operation" => op,
          "at"        => now_iso
        }) + "\n")
      }
    end

    if skip
      STDERR.write("freshness-gate: gate=bypassed source=#{src} operation=#{op} reason=operator-bypass\n")
      exit 0
    end

    if fresh
      STDERR.write("freshness-gate: gate=pass source=#{src} operation=#{op}\n")
      exit 0
    else
      STDERR.write("freshness-gate: gate=block reason=stale source=#{src} age_seconds=#{age.to_i} window=#{win}\n")
      exit 1
    end
RUBY
  return $?
}

# Detect §2.17-mode by scanning args for --operation. If present, run the
# §2.17 handler with the caller-set F217_LAST_FETCH_DIR and exit. Else
# return 100 so the caller continues with its legacy logic.
f217_detect_and_run() {
  for a in "$@"; do
    if [ "$a" = "--operation" ]; then
      f217_run "$@"
      exit $?
    fi
  done
  return 100  # not a §2.17 invocation
}
