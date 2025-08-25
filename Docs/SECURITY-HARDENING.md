# Security Hardening Guide

This document summarizes practical steps to reduce attack surface and defend against Red Team tactics.

## Secrets & Credentials
- Use GitHub Actions secrets and local env vars; never commit secrets.
- Secret scanning: PRs are scanned by Gitleaks (Secret Scan workflow).
- Consider adding push protection in org settings.

## Supply Chain
- CodeQL runs on push/PR; fix alerts promptly.
- Dependency review blocks critical advisories on PRs.
- Dependabot updates for SwiftPM and Actions run weekly.
- Pin SPM dependencies via `Package.resolved` (committed).

## Build & Signing
- Prefer reproducible builds and keep `Package.swift` minimal.
- Enforce code signing for release targets in Xcode (CI uses unsigned builds).
- Consider enabling required signed commits via branch protection.

## App Hardening
- Review `AI-Mixtapes.entitlements` regularly; remove unnecessary capabilities.
- Validate Info.plist keys: network, privacy, background modes.
- Limit network domains; prefer ATS defaults.
- Gate debug features behind compile flags.

## CI/CD
- paths-ignore prevents doc/image‑only runs to reduce surface area.
- Concurrency cancels stale runs.
- Cache is scoped by Package.resolved hash to avoid poisoning.

## Logging & Telemetry
- Avoid logging PII; set appropriate log levels per configuration.
- Use `Release.xcconfig` to keep logs minimal in production.

## Threat Modeling (Quick)
- Data exposure: review persistence and IPC boundaries.
- MITM/Injection: validate inputs, prefer HTTPS, avoid dynamic code eval.
- Lateral movement: minimize entitlements, sandbox enabled.

## Incident Response
- Revoke and rotate any exposed credentials immediately.
- Invalidate released artifacts if necessary; issue a security advisory.
- Add regression tests for the vulnerable path.
