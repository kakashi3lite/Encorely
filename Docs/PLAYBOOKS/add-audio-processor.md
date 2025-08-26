# Playbook: Add an Audio Processor

1) Define processor
- Location: `Sources/AudioKitEncorely/DSP/`
- Keep it pure and testable; avoid UI concerns.

2) Session integration
- Use `AudioSessionManager` for session configuration.

3) App service
- Add an adapter in `Sources/App/Consolidated/Services/Audio*` to invoke the DSP.

4) Tests
- Add unit tests under `Tests/AudioKitEncorelyTests/`.

5) Performance
- Validate with `PerformanceMonitor`/`PerformanceValidator` if applicable.
