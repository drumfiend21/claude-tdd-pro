---
name: Commit + push cadence — work preservation against ephemeral containers
description: The remote branch is the only durable store. Claude Code on the web runs in an ephemeral container that can be reclaimed and re-cloned between turns, silently resetting the local working tree to the last-pushed remote state. Commit AND push at every natural sub-boundary, always and without fail. Never let work exist only in the local working tree.
type: feedback
---

## The invariant (non-negotiable)

**The remote branch `origin/<feature-branch>` is the ONLY durable store of your work.**
Anything that exists only in the local working tree or in a local-but-unpushed
commit can vanish without warning — no error, no prompt.

## The failure mode

This project runs in a managed, ephemeral remote-execution container (Claude
Code on the web). The container is reclaimed after inactivity or between turns,
and the repo is re-cloned fresh on resume. The re-clone lands at whatever the
remote branch pointed to at clone time — which may be BEHIND your local work if
you committed/edited and did not push. Observed in this project 2026-06-08:
mid-build, the local tree reset to a commit two CLs back (twice in one session);
only because the work had been pushed was it recoverable via `git fetch` +
`git merge --ff-only`. Un-pushed local commits and uncommitted edits would have
been lost outright.

## The rules — always and without fail

1. **Push every commit immediately.** A commit is not "done" until it is on the
   remote. Commit and push are a single inseparable step:
   `git -c commit.gpgsign=false commit -F <body> && git push -u origin <branch>`.
   Never leave a local commit unpushed across a tool call, let alone a turn.

2. **Checkpoint at every natural sub-boundary within a CL — do not wait for CL
   completion.** Commit+push after each durable milestone:
   - specs authored + JSON-valid + §25 fidelity-clean (before building substrate);
   - substrate built + feature probe green (before the full-suite wait);
   - full suite green (the CL-completion commit with the audit body).
   A re-clone then costs at most one sub-step, never a whole CL.

3. **Never end a turn with uncommitted non-trivial work.** If a turn must end
   (waiting on a long suite, blocked, handing off), commit+push a WIP checkpoint
   first. The stop-hook "uncommitted changes" message is a HARD prompt to
   commit+push, not a nuisance to acknowledge and move past.

4. **Reconcile with the remote at the start of every working turn.** Before
   editing, assume nothing about local == remote. Run
   `git fetch origin <branch>` and fast-forward (`git merge --ff-only
   origin/<branch>`). If files you know you created are missing, this is a
   re-clone — recover from the remote before redoing work.

5. **Verify the push landed.** Confirm `origin/<branch>` advanced
   (`git rev-parse origin/<branch>` matches `HEAD`). On network failure, retry
   with exponential backoff (2s/4s/8s/16s) per the Git Operations policy. Treat
   a silent non-push as a failure, not a success.

6. **All checkpoints go to the designated feature branch — never another
   branch, never detached.** Work preservation never justifies pushing
   elsewhere.

## Standing authorization

This directive constitutes durable authorization to commit AND push
work-preserving checkpoints WITHOUT a separate per-commit approval prompt. It
narrows — it does not remove — `CLAUDE.md` Step 4: the CL-completion commit
still carries the full audit-findings body and is the reviewable unit. WIP
checkpoints are preservation snapshots; they need no approval, because standing
instruction already gave it ("make frequent commit+push the standard, always
and without fail," 2026-06-08).

## Why this is cheap

Push is near-instant on this remote. Frequent pushes also de-risk every other
failure mode (crash, timeout, context loss). The cost of one extra push is
seconds; the cost of one lost CL is the whole build cycle re-done. Delete
nothing here (Musk step 2 does not apply to durability guarantees).

Persisted 2026-06-08 after a re-clone reset the local tree mid-build (twice);
recovered only because the work had been pushed.
