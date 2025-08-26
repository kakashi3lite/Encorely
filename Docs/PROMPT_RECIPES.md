# Prompt Recipes (Context-Saving)

Use these minimal, high-signal prompts to guide AI tools.

## Add a Button to a Screen
- Task: Add a "Shuffle" button to MixTapeView.
- Files: `Sources/App/Consolidated/MixTapeView.swift`
- Excerpt: Provide 20–40 lines around the place you want to insert.
- Constraints: Respect SwiftLint rules; add accessibility label.

## Hook a New Socket Event
- Task: Handle `playlist:recommendations` event.
- Files: `Sources/MCPClient/MCPClient.swift`
- Excerpt: Show existing event handlers and target injection points.
- Constraints: Keep parsing pure; pass to service via DI.

## Add a Data Model
- Task: Add `UserPreference` model.
- Files: `Sources/SharedTypes/` (new file) and any usage site.
- Excerpt: Where it is consumed; do not paste entire file.

General tips:
- Link to `Docs/CODE_CONTEXT.md` and `Docs/ARCHITECTURE.md` instead of pasting large files.
- Provide narrow code snippets and exact file paths.
