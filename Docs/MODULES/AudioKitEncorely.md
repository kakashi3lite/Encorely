# Module: AudioKitEncorely

Purpose: Audio DSP utilities and session helpers built on AudioKit.

Key files:
- Sources/AudioKitEncorely/DSP/RMS.swift — RMS calculation utilities
- Sources/AudioKitEncorely/Session/AudioSessionManager.swift — audio session management

Usage:
- Call DSP utilities from app services (`Consolidated/Services/Audio*`).
- Manage session lifecycle via `AudioSessionManager` in app entry and foreground/background handlers.

Testing:
- Unit tests under `Tests/AudioKitEncorelyTests/` (e.g., RMSTests.swift).
