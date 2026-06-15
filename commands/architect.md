---
name: architect
description: Turn a plain-language feature or app vision into a grounded architecture — decomposes it into decision points, enumerates options cited to tier-1 sources (standards / PR-corpus / compliance), prompts you per decision, and writes ADRs. Loads the architect skill.
disable-model-invocation: true
---

The user wants to design a feature or an application's architecture from a
plain-language description (they may be non-technical). Load the `architect`
skill and follow it precisely: decompose the description into discrete decision
points, enumerate grounded options per S/L/C source for each, prompt the user per
decision in business language, and record the chosen decisions as ADRs.

For a full guided cloud-architecture session (intake → translate → recommend →
review → ADR → build), the skill drives `commands/architect-session.sh`.

Feature or app vision: $ARGUMENTS
