# ADR-0003: Core Data Versioning and Migrations

- Status: accepted
- Date: 2025-08-24
- Deciders: @kakashi3lite
- Tags: persistence, coredata, data-model

## Context
We maintain Core Data models (`AI_Mixtapes.xcdatamodeld`, `Mixtapes.xcdatamodeld`). Migrations must be predictable and documented.

## Decision
- Use lightweight migrations by default.
- Add mapping models only when needed (include them in the repo under the model bundle).
- Maintain a migration guide per version bump and test with sample stores.

## Consequences
- Predictable upgrades; minimal runtime surprises.
- Slight overhead to keep migration notes and tests.

## Links
- Docs/DEV_NOTES.md
