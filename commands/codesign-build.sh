#!/usr/bin/env bash
# commands/codesign-build.sh — §28.62 full-stack-FOR-CLOUD co-design: couple the TWO build flows
# (application code + IaC/cloud) so each informs the other. Composes S-50 (decision) + S-52/S-53
# (full-stack design) + S-29 (IaC build units) + O-12 (app scaffolds) — NO new feature ID.
#
# From the S-33 technical-requirements (full-stack pillars) + a target cloud platform it derives, for one
# decision, BOTH:
#   - application build units  (backend-api / frontend / database / realtime-service / auth-service),
#     each declaring the cloud infrastructure it REQUIRES;
#   - infrastructure build units (compute / managed-database / cdn / websocket-infra / secrets-iam),
#     each declaring the application component it SERVES;
# and reconciles them: `reconciled=true` iff every app unit's required infra is present AND every infra
# unit serves an app unit. This is the bidirectional "inform each other" link — the app is built FOR the
# cloud, and the cloud is provisioned FOR the app, from the same design.
#
# CLI: --requirements <technical-requirements.json> --platform <aws|gcp|azure> [--decision-id <id>] [--json]
# stderr: per app unit `codesign app=<unit> stack=<s> requires=<infra-csv>`;
#         per infra unit `codesign infra=<unit> serves=<app-csv>`;
#         summary `codesign platform=<p> app_units=<n> infra_units=<n> reconciled=<true|false>`
# Exit: 0 reconciled | 1 not reconciled | 2 usage.
set -uo pipefail
REQ=""; PLATFORM=""; DID="d1"; JSON=0; TOOLCHAIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --requirements) REQ="${2-}"; shift 2 ;;
    --platform)     PLATFORM="${2-}"; shift 2 ;;
    --decision-id)  DID="${2-}"; shift 2 ;;
    --toolchain)    TOOLCHAIN="${2-}"; shift 2 ;;
    --json)         JSON=1; shift ;;
    -h|--help) echo "Usage: codesign-build.sh --requirements <technical-requirements.json> --platform <aws|gcp|azure> [--decision-id <id>] [--toolchain <json>] [--json]" >&2; exit 0 ;;
    *) echo "codesign-build: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$REQ" ] && { echo "codesign-build: --requirements <json> required" >&2; exit 2; }
[ -f "$REQ" ] || { echo "codesign-build: not a file: $REQ" >&2; exit 2; }
case "$PLATFORM" in aws|gcp|azure) : ;; *) echo "codesign-build: --platform aws|gcp|azure required" >&2; exit 2 ;; esac

REQ="$REQ" PLATFORM="$PLATFORM" DID="$DID" JSON="$JSON" TOOLCHAIN="$TOOLCHAIN" node -e '
  const fs=require("fs");
  let tr; try{ tr=JSON.parse(fs.readFileSync(process.env.REQ,"utf8")); }catch(e){ process.stderr.write("codesign-build: requirements not valid json\n"); process.exit(2); }
  const pillars = tr.pillars||{};
  const has = k => Array.isArray(pillars[k]) && pillars[k].length>0;
  const plat = process.env.PLATFORM;
  // platform-native infra names (the cloud the app is built FOR)
  // platform-native infra for a full DISTRIBUTED SYSTEM: compute, relational (SQL) + document (NoSQL)
  // databases, message broker (queues), CDN (frontend delivery), websocket, secrets.
  const NAT = {
    aws:   { compute:"ecs-fargate", sqldb:"rds", nosqldb:"dynamodb", mq:"sqs", cdn:"cloudfront", ws:"api-gateway-websocket", sec:"secrets-manager+iam" },
    gcp:   { compute:"cloud-run",   sqldb:"cloud-sql", nosqldb:"firestore", mq:"pubsub", cdn:"cloud-cdn", ws:"cloud-run-websocket", sec:"secret-manager+iam" },
    azure: { compute:"container-apps", sqldb:"azure-sql", nosqldb:"cosmos-db", mq:"service-bus", cdn:"azure-cdn", ws:"web-pubsub", sec:"key-vault+rbac" },
  }[plat];
  // application build unit -> (component ROLE, required infra key). Derived from the full-stack design
  // pillars. LANGUAGE/FRAMEWORK-AGNOSTIC: the unit names the component role, NOT a fixed stack — the
  // actual language/framework is chosen by the S-45 toolchain-advisor per the problem + whatever rules
  // were scraped (and may be overridden via --toolchain). `stack` defaults to `toolchain-selected`.
  let tc = {}; try { if(process.env.TOOLCHAIN) tc = JSON.parse(fs.readFileSync(process.env.TOOLCHAIN,"utf8")); } catch(e){}
  const stackFor = role => (tc.stacks && tc.stacks[role]) || (tc[role]) || "toolchain-selected";
  const distributed = has("distributed")||has("integration")||has("realtime");  // polyglot persistence + messaging
  const APP = [];
  if (has("api")||has("integration")) APP.push({unit:"backend-api", stack:stackFor("backend-api"), requires:["compute"]});       // REST API / BE
  if (has("frontend")||has("edge"))   APP.push({unit:"frontend",    stack:stackFor("frontend"),    requires:["cdn"]});           // FE
  if (has("integration"))             APP.push({unit:"message-queue", stack:stackFor("message-queue"), requires:["mq"]});         // messaging queue
  if (has("data")||has("storage"))    APP.push({unit:"sql-database",  stack:stackFor("sql-database"),  requires:["sqldb"]});      // relational (SQL)
  if ((has("data")||has("storage")) && distributed) APP.push({unit:"nosql-database", stack:stackFor("nosql-database"), requires:["nosqldb"]}); // document (NoSQL)
  if (has("realtime"))                APP.push({unit:"realtime-service", stack:stackFor("realtime-service"), requires:["compute","ws"]});
  if (has("identity"))                APP.push({unit:"auth-service", stack:stackFor("auth-service"), requires:["sec"]});
  // infra build unit per required infra key, annotated with which app unit(s) it serves.
  const infraKeys = [...new Set(APP.flatMap(a=>a.requires))];
  const INFRA = infraKeys.map(k=>({
    unit: NAT[k], key:k,
    serves: APP.filter(a=>a.requires.includes(k)).map(a=>a.unit),
  }));
  // reconcile: every app requirement has an infra unit AND every infra serves >=1 app.
  const infraPresent = new Set(INFRA.map(i=>i.key));
  const appOk  = APP.every(a=>a.requires.every(k=>infraPresent.has(k)));
  const infraOk= INFRA.every(i=>i.serves.length>0);
  const reconciled = APP.length>0 && appOk && infraOk;

  for(const a of APP) process.stderr.write(`codesign app=${a.unit} stack=${a.stack} requires=${a.requires.map(k=>NAT[k]).join(",")}\n`);
  for(const i of INFRA) process.stderr.write(`codesign infra=${i.unit} serves=${i.serves.join(",")}\n`);
  process.stderr.write(`codesign platform=${plat} app_units=${APP.length} infra_units=${INFRA.length} reconciled=${reconciled}\n`);

  const plan = {
    schema_version:"1.0", decision_id:process.env.DID, platform:plat,
    app_units: APP.map(a=>({unit:a.unit, stack:a.stack, requires_infra:a.requires.map(k=>NAT[k])})),
    infra_units: INFRA.map(i=>({unit:i.unit, serves_app:i.serves})),
    reconciled,
  };
  if(process.env.JSON==="1") process.stdout.write(JSON.stringify(plan,null,2));
  process.exit(reconciled?0:1);
'
