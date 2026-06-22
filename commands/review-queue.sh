#!/usr/bin/env bash
# commands/review-queue.sh — ADR-0009 stage 6: route drafted rules to a review queue by
# confidence + coverage, the human-in-the-loop gate before a rule reaches active.json.
#
# Routing (per ADR-0009): for each draft (draft-custom-rule.sh output)
#   high-confidence + zero-gap   -> auto-stage   (batched commit; bulk-accept with --auto-accept)
#   high-confidence + gaps       -> coverage-review (operator reviews the clause coverage report)
#   low/medium confidence        -> side-by-side-review (prose vs draft, full operator review)
# where confidence=high iff >=1 clause got a deterministic tool DSL (clauses_covered>0), and a
# "gap" is a clause flagged unenforceable (needs operator sign-off). Default is human-in-the-loop;
# --auto-accept opts a high-trust operator into auto-staging the high-confidence zero-gap rules.
#
# CLI: (--in <draft.json> [--in ...] | --dir <dir>) [--auto-accept] [--json]
# stderr: per draft `review-queue rule=<id> confidence=<h|l> gaps=<n> queue=<...>`; summary
#         `review-queue total=<t> auto_stage=<a> coverage_review=<c> side_by_side=<s> staged=<n>`
# stdout (--json): { queues: {...}, staged: [...] }
# Exit: 0 ok | 2 usage.

set -uo pipefail
INS=(); DIR=""; AUTO=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --in) INS+=("${2-}"); shift 2 ;;
    --dir) DIR="${2-}"; shift 2 ;;
    --auto-accept) AUTO=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) echo "Usage: review-queue.sh (--in <draft.json> | --dir <dir>) [--auto-accept] [--json]" >&2; exit 0 ;;
    *) echo "review-queue: unknown arg: $1" >&2; exit 2 ;;
  esac
done
command -v node >/dev/null 2>&1 || { echo "review-queue: node required" >&2; exit 2; }
[ ${#INS[@]} -eq 0 ] && [ -z "$DIR" ] && { echo "review-queue: --in <draft.json> or --dir <dir> required" >&2; exit 2; }

INPUTS_CSV="$(IFS=,; echo "${INS[*]:-}")" DIR="$DIR" AUTO="$AUTO" JSON="$JSON" node -e '
  const fs=require("fs"),path=require("path");
  const auto=process.env.AUTO==="1", wantJson=process.env.JSON==="1";
  let files=(process.env.INPUTS_CSV||"").split(",").filter(Boolean);
  const dir=process.env.DIR||"";
  if(dir){ try{ for(const e of fs.readdirSync(dir)) if(e.endsWith(".json")) files.push(path.join(dir,e)); }catch(e){} }
  files=[...new Set(files)];

  const queues={ "auto-stage":[], "coverage-review":[], "side-by-side-review":[] };
  const staged=[];
  let total=0;
  for(const f of files){
    let d; try{ d=JSON.parse(fs.readFileSync(f,"utf8")); }catch(e){ continue; }
    if(!d || !d.rule_id) continue;
    total++;
    const covered = d.clauses_covered||0;
    const gaps = d.clauses_unenforceable||0;
    const confidence = covered>0 ? "high" : "low";
    let queue;
    if(confidence==="high" && gaps===0) queue="auto-stage";
    else if(confidence==="high") queue="coverage-review";
    else queue="side-by-side-review";
    queues[queue].push(d.rule_id);
    if(queue==="auto-stage" && auto) staged.push(d.rule_id);
    process.stderr.write(`review-queue rule=${d.rule_id} confidence=${confidence} gaps=${gaps} queue=${queue}\n`);
  }
  if(wantJson) process.stdout.write(JSON.stringify({queues, staged}));
  process.stderr.write(`review-queue total=${total} auto_stage=${queues["auto-stage"].length} coverage_review=${queues["coverage-review"].length} side_by_side=${queues["side-by-side-review"].length} staged=${staged.length}\n`);
'
