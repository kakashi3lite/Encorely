# Runbook: CI Failures

1) Read job summary and logs.
2) For dependency issues: clear caches step-by-step, confirm Package.resolved.
3) For test flakes: re-run single job; quarantine if necessary.
4) For code style: run SwiftFormat/SwiftLint locally.
