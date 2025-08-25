# VS Code Setup for Encorely Development

This guide helps you set up Visual Studio Code for iOS/Swift (Swift 6) development with Encorely.

## Prerequisites

1. Install Xcode from the Mac App Store
2. Install required tools via Homebrew:
```bash
brew install sourcekit-lsp
brew install swiftlint
brew install swiftformat
```

## Required VS Code Extensions

Install the following extensions:

1. **Core Swift Development:**
   - CodeLLDB (`vadimcn.vscode-lldb`)
   - Swift Language (`Kasik96.swift`)
   - SourceKit-LSP (`sourcekit-lsp.sourcekit-lsp`)

2. **Git Integration:**
   - GitLens (`eamodio.gitlens`)
   - Git History (`donjayamanne.githistory`)

3. **Code Quality:**
   - SwiftLint (`vknabel.vscode-swiftlint`)
   - SwiftFormat (`vknabel.vscode-swiftformat`)

4. **Productivity:**
   - Path Intellisense (`christian-kohler.path-intellisense`)
   - Better Comments (`aaron-bond.better-comments`)
   - Error Lens (`usernamehw.errorlens`)

## Workspace Configuration

The `.vscode` folder contains the following configuration files:

1. `settings.json`: Editor settings and Swift/LLDB configurations
2. `launch.json`: Debug configurations for running the app and tests
3. `tasks.json`: Build, test, and code quality tasks

## Available Tasks

Access these tasks via Command Palette (Cmd+Shift+P) > "Tasks: Run Task":

- **Build Tasks:**
  - `Build for Mac`: Build release version
  - `Build for Debug`: Build debug version
  - `Clean Build`: Clean build artifacts

- **Test Tasks:**
  - `Run All Tests`: Run all test suites
  - `Run Performance Tests`: Run performance test suite

- **Code Quality:**
  - `SwiftLint`: Run SwiftLint checks
  - `SwiftFormat`: Format Swift code

## Debug Configurations

Available via Run & Debug panel (Cmd+Shift+D):

1. `Run Encorely`: Launch release build
2. `Run Encorely (Debug)`: Launch debug build
3. `Run Tests`: Run test suite

## Keyboard Shortcuts

- Build: Cmd+Shift+B
- Run Tests: Cmd+Shift+T
- Start Debugging: F5
- Toggle Breakpoint: F9
- Step Over: F10
- Step Into: F11

## Best Practices

1. Always run SwiftLint before committing changes
2. Use SwiftFormat to maintain consistent code style
3. Enable "Format on Save" for automatic formatting
4. Use GitLens blame annotations to track changes
5. Utilize the integrated debugger with breakpoints

## Troubleshooting

If you encounter issues:

1. Verify that SourceKit-LSP is properly installed:
```bash
which sourcekit-lsp
```

2. Check Swift toolchain location:
```bash
xcrun --find swift
```

3. Restart the SourceKit-LSP server:
   - Cmd+Shift+P > "SourceKit-LSP: Restart Server"

4. Clear VS Code cache:
   - Cmd+Shift+P > "Developer: Reload Window"
