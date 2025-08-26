# Docs Index

High-signal references for Encorely development:

- CODE_CONTEXT.md — codebase map and quick pointers
- ARCHITECTURE.md — layered design, runtime flow, key packages
- DEV_NOTES.md — setup, run, lint/format, troubleshooting
- AI_GUIDE.md — prompting AI tools with minimal context
- SECURITY-HARDENING.md — hardening practices and threat model

CI & Policies:
- .github/workflows/swift6-ci.yml — Swift 6 primary CI (cached)
- .github/workflows/codeql.yml — static analysis (CodeQL)
- .github/workflows/secret-scan.yml — secret scanning via Gitleaks
- .github/workflows/dependency-review.yml — PR dependency review
- SECURITY.md — reporting vulnerabilities
- .github/CODEOWNERS — ownership map



New references:
- ADRs: Docs/ADR/0002-consolidated-modules.md, Docs/ADR/0003-coredata-migrations.md
- Guidelines: Docs/ACCESSIBILITY.md, Docs/STATE_MANAGEMENT.md, Docs/DESIGN_SYSTEM.md
- Performance: Docs/PERFORMANCE_PROFILING.md
- Runbooks: Docs/RUNBOOKS/ci-failures.md, Docs/RUNBOOKS/crash-symbolication.md
- DocC: Sources/App/Encorely.docc (Xcode Quick Help)
