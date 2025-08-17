# Security Policy

## Supported Versions
- Active development on the main branch.

## Reporting a Vulnerability
- Please email security reports to the repository owner via GitHub or open a private advisory in GitHub Security Advisories.
- Do not create public issues for vulnerabilities.
- We aim to acknowledge within 72 hours and provide a fix or mitigation as soon as possible.

## Guidelines
- Never commit secrets to the repo.
- Prefer Keychain/Secure Enclave for credentials and keys.
- Encrypt sensitive exports (e.g., audio) with AES-256-GCM; wipe temp files.
