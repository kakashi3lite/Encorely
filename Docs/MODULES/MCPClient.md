# Module: MCPClient

Purpose: Socket.IO client and protocol models for external integrations.

Key files:
- Sources/MCPClient/MCPClient.swift — primary client and event handling
- Sources/MCPClient/* — related models/utilities

Usage:
- Inject into app services via DI; keep UI separate from socket event handling.

Testing:
- Add unit tests for protocol parsing and reconnection logic under `Tests/`.
