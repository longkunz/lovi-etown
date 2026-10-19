# Domain Docs

Layout: **single-context** for Lovi Etown, with `CONTEXT.md` at the repo root and decisions in `docs/adr/`.

## Before exploring, read these

- Root `CONTEXT.md` for domain terms and context.
- ADRs in `docs/adr/` that touch the area you are about to work in.
- If root `CONTEXT-MAP.md` exists in the future, follow its pointers to each relevant context instead.

If these files do not exist, proceed silently. The `domain-modeling` skill, reached through `grill-with-docs` or `improve-codebase-architecture`, creates them lazily when terms or decisions get resolved.

## File structure

```text
/
├── CONTEXT.md
└── docs/
    └── adr/
        └── 0001-<decision>.md
```

These paths describe where domain documents belong when created; setup does not create placeholder domain documents.

## Use the glossary's vocabulary

When naming domain concepts in issue titles, refactor proposals, hypotheses, or tests, use the terms defined in `CONTEXT.md`.

If a needed concept is absent, reconsider whether the project uses it; note a real terminology gap for `domain-modeling`.

## Flag ADR conflicts

If a proposal contradicts an existing ADR, name the ADR explicitly and explain why the decision should be reopened.
