# Security Policy

We take security seriously and welcome responsible disclosure.

## Reporting a Vulnerability
- Email: security@encorely.dev (or open a private security advisory via GitHub Security Advisories)
- Please include: affected versions, reproduction steps, impact, and suggested fixes if known.
- We aim to acknowledge within 48 hours.

## Supported Versions
- Main branch is supported and monitored via CodeQL and secret scans.
- Older snapshots may not receive patches.

## Hardening Guidance
- Never commit secrets; use environment variables and GitHub Actions secrets.
- Validate third‑party dependencies; PRs must pass dependency review.
- Keep Xcode/Swift toolchains up to date (Swift 6 / Xcode 26+).
- Review entitlements (`AI-Mixtapes.entitlements`) and Info.plist keys before release.

See also: Docs/SECURITY-HARDENING.md
