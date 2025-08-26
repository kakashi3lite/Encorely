# ADR-0002: Consolidated App Module Strategy

- Status: accepted
- Date: 2025-08-24
- Deciders: @kakashi3lite
- Tags: modules, architecture, organization

## Context
Historically, code lived under legacy paths (`Sources/AIMixtapes`, `Sources/AI-Mixtapes`). This increased duplication and made navigation harder. We needed a single, obvious home for new app code.

## Decision
Adopt `Sources/App/Consolidated/` as the canonical surface for app code (views, services, DI, models, resources). Legacy paths remain for history but should not receive new code.

## Consequences
- Positive: Faster navigation, clearer ownership, simpler onboarding.
- Tradeoffs: Short-term mixed naming in the Xcode project until a full rename is performed.

## Alternatives Considered
- Multiple feature packages: Adds ceremony and indirection; not yet needed.

## Links
- Docs/CODE_CONTEXT.md
- Docs/MODULES/App.md
