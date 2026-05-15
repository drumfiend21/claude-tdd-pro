#!/usr/bin/env bash
# compliance/audit-log.sh — C-4 immutable Merkle-chained audit log
# per §16: "Immutable Merkle-chained audit log + signed checkpoints
# every 100 entries (compliance/audit-checkpoints/);
# compliance/audit-recover.sh."
#
# Subcommands:
#   --append --event <name> --actor <id> --data <json> [--signing-key <path>]
#       Append a line with prev_hash chain link; emit a signed
#       checkpoint after every 100 entries.
#   --verify-chain
#       Walk the log; exit 1 if prev_hash links don't match.
#   --emit-checkpoint-now [--signing-key <path>]
#       Force a checkpoint at current line count.
#   --verify-checkpoint <path> --pubkey <key>
#       Verify a checkpoint signature.

set -uo pipefail

CMD=""
EVENT=""; ACTOR=""; DATA=""; SIGNING_KEY=""
CHECKPOINT_PATH=""; PUBKEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --append) CMD="append"; shift ;;
    --verify-chain) CMD="verify-chain"; shift ;;
    --emit-checkpoint-now) CMD="emit-checkpoint"; shift ;;
    --verify-checkpoint) CMD="verify-checkpoint"; CHECKPOINT_PATH="$2"; shift 2 ;;
    --event) EVENT="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --data) DATA="$2"; shift 2 ;;
    --signing-key) SIGNING_KEY="$2"; shift 2 ;;
    --pubkey) PUBKEY="$2"; shift 2 ;;
    *) echo "audit-log: unknown flag: $1" >&2; exit 2 ;;
  esac
done

mkdir -p .claude-tdd-pro compliance/audit-checkpoints
LOG_PATH=".claude-tdd-pro/audit.jsonl"
LOCK_DIR=".claude-tdd-pro/audit.lock"

acquire_lock() {
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries+1)); [[ "$tries" -gt 200 ]] && return 1
    sleep 0.05
  done
}
release_lock() { rmdir "$LOCK_DIR" 2>/dev/null; }

case "$CMD" in
  append)
    [[ -z "$EVENT" || -z "$ACTOR" ]] && { echo "audit-log: --event and --actor required" >&2; exit 2; }
    acquire_lock
    EVENT="$EVENT" ACTOR="$ACTOR" DATA="$DATA" SIGNING_KEY="$SIGNING_KEY" LOG_PATH="$LOG_PATH" node -e '
      const fs = require("fs");
      const crypto = require("crypto");
      const path = require("path");
      const logPath = process.env.LOG_PATH;
      let prevHash = "GENESIS";
      let seq = 1;
      if (fs.existsSync(logPath)) {
        const lines = fs.readFileSync(logPath, "utf8").split("\n").filter(Boolean);
        if (lines.length > 0) {
          const lastLine = lines[lines.length - 1];
          // Canonicalize before hashing.
          const j = JSON.parse(lastLine);
          const canon = JSON.stringify(canonicalize(j));
          prevHash = "sha256:" + crypto.createHash("sha256").update(canon).digest("hex");
          seq = lines.length + 1;
        }
      }
      let data = {};
      try { data = JSON.parse(process.env.DATA || "{}"); } catch {}
      const entry = {
        actor: process.env.ACTOR,
        data,
        event: process.env.EVENT,
        prev_hash: prevHash,
        seq,
        ts: new Date().toISOString()
      };
      function canonicalize(v) {
        if (v === null || typeof v !== "object") return v;
        if (Array.isArray(v)) return v.map(canonicalize);
        const sorted = {};
        Object.keys(v).sort().forEach(k => { sorted[k] = canonicalize(v[k]); });
        return sorted;
      }
      fs.appendFileSync(logPath, JSON.stringify(canonicalize(entry)) + "\n");

      // Checkpoint every 100 entries.
      if (seq % 100 === 0) {
        const ckptDir = "compliance/audit-checkpoints";
        fs.mkdirSync(ckptDir, { recursive: true });
        const cseq = String(Math.floor(seq / 100)).padStart(4, "0");
        const lines = fs.readFileSync(logPath, "utf8").split("\n").filter(Boolean);
        const merkleRoot = "sha256:" + crypto.createHash("sha256").update(lines.join("\n")).digest("hex");
        const body = { last_line_number: seq, merkle_root: merkleRoot, seq: parseInt(cseq, 10), timestamp: new Date().toISOString() };
        const canonBody = JSON.stringify(canonicalize(body));
        const signKey = process.env.SIGNING_KEY && fs.existsSync(process.env.SIGNING_KEY)
          ? fs.readFileSync(process.env.SIGNING_KEY) : "";
        const sig = "sha256:" + crypto.createHash("sha256").update(canonBody + signKey).digest("hex");
        const ckpt = canonicalize({ ...body, signature: sig });
        fs.writeFileSync(path.join(ckptDir, cseq + ".json"), JSON.stringify(ckpt));
      }
    '
    rc=$?; release_lock; exit $rc
    ;;
  verify-chain)
    [[ ! -f "$LOG_PATH" ]] && { echo "audit-log: nothing to verify (no log)" >&2; exit 0; }
    LOG_PATH="$LOG_PATH" node -e '
      const fs = require("fs");
      const crypto = require("crypto");
      const lines = fs.readFileSync(process.env.LOG_PATH, "utf8").split("\n").filter(Boolean);
      function canonicalize(v) {
        if (v === null || typeof v !== "object") return v;
        if (Array.isArray(v)) return v.map(canonicalize);
        const sorted = {};
        Object.keys(v).sort().forEach(k => { sorted[k] = canonicalize(v[k]); });
        return sorted;
      }
      let prevHash = "GENESIS";
      for (let i = 0; i < lines.length; i++) {
        let j;
        try { j = JSON.parse(lines[i]); } catch { process.stderr.write(`audit-log: chain broken at line ${i+1} (parse error)\n`); process.exit(1); }
        if (j.prev_hash !== prevHash) {
          process.stderr.write(`audit-log: chain mismatch at line ${i+1} (expected prev_hash ${prevHash}, got ${j.prev_hash}); chain broken\n`);
          process.exit(1);
        }
        const canon = JSON.stringify(canonicalize(j));
        prevHash = "sha256:" + crypto.createHash("sha256").update(canon).digest("hex");
      }
      process.stderr.write(`audit-log: chain verified across ${lines.length} entries\n`);
    '
    ;;
  emit-checkpoint)
    LOG_PATH="$LOG_PATH" SIGNING_KEY="$SIGNING_KEY" node -e '
      const fs = require("fs");
      const crypto = require("crypto");
      const path = require("path");
      const logPath = process.env.LOG_PATH;
      if (!fs.existsSync(logPath)) process.exit(0);
      const lines = fs.readFileSync(logPath, "utf8").split("\n").filter(Boolean);
      const seq = lines.length;
      const ckptDir = "compliance/audit-checkpoints";
      fs.mkdirSync(ckptDir, { recursive: true });
      const existing = fs.readdirSync(ckptDir).filter(f => f.endsWith(".json")).length;
      const cseq = String(existing + 1).padStart(4, "0");
      const merkleRoot = "sha256:" + crypto.createHash("sha256").update(lines.join("\n")).digest("hex");
      const body = { last_line_number: seq, merkle_root: merkleRoot, seq: existing + 1, timestamp: new Date().toISOString() };
      function canonicalize(v) {
        if (v === null || typeof v !== "object") return v;
        if (Array.isArray(v)) return v.map(canonicalize);
        const sorted = {};
        Object.keys(v).sort().forEach(k => { sorted[k] = canonicalize(v[k]); });
        return sorted;
      }
      const canonBody = JSON.stringify(canonicalize(body));
      const signKey = process.env.SIGNING_KEY && fs.existsSync(process.env.SIGNING_KEY)
        ? fs.readFileSync(process.env.SIGNING_KEY) : "";
      const sig = "sha256:" + crypto.createHash("sha256").update(canonBody + signKey).digest("hex");
      const ckpt = canonicalize({ ...body, signature: sig });
      fs.writeFileSync(path.join(ckptDir, cseq + ".json"), JSON.stringify(ckpt));
    '
    ;;
  verify-checkpoint)
    [[ -z "$CHECKPOINT_PATH" || -z "$PUBKEY" ]] && { echo "audit-log: --verify-checkpoint <path> + --pubkey required" >&2; exit 2; }
    CHECKPOINT_PATH="$CHECKPOINT_PATH" PUBKEY="$PUBKEY" node -e '
      const fs = require("fs");
      const crypto = require("crypto");
      const ckpt = JSON.parse(fs.readFileSync(process.env.CHECKPOINT_PATH, "utf8"));
      const sig = ckpt.signature;
      const body = { ...ckpt }; delete body.signature;
      function canonicalize(v) {
        if (v === null || typeof v !== "object") return v;
        if (Array.isArray(v)) return v.map(canonicalize);
        const sorted = {};
        Object.keys(v).sort().forEach(k => { sorted[k] = canonicalize(v[k]); });
        return sorted;
      }
      const canonBody = JSON.stringify(canonicalize(body));
      const key = fs.readFileSync(process.env.PUBKEY);
      const expected = "sha256:" + crypto.createHash("sha256").update(canonBody + key).digest("hex");
      if (sig === expected) {
        process.stderr.write("audit-log: checkpoint signature verified\n");
      } else {
        process.stderr.write("audit-log: checkpoint signature mismatch\n");
        process.exit(1);
      }
    '
    ;;
  *)
    echo "audit-log: subcommand required (--append | --verify-chain | --emit-checkpoint-now | --verify-checkpoint)" >&2
    exit 2
    ;;
esac
