---
name: profile-suggest
description: First-session scan that suggests an appropriate risk-tier profile based on stack signals (package.json, requirements.txt), compliance signals (compliance/ folder), financial vocabulary (PCI, ledger, transaction in README), and government signals (FedRAMP, FISMA, NIST 800-53 in README).
trigger: SessionStart
first_session_only: true
---

# Profile Suggest

On first session, scans the repo and suggests a profile tier:
- **high-risk**: government / financial / compliance signals present
- **regulated**: any compliance folder / framework reference
- **strict**: stack identifiable but no compliance signals
- **baseline**: nothing detected

Persists user decision in `.claude-tdd-pro/profile-suggest-state.json`.
Once accepted or declined, never prompts again.
