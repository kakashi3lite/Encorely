# Contributing to Encorely

## 🎯 Development Standards

### AI-First Development
1. **Feature Planning**
   - Start with "How can AI enhance this feature?"
   - Document AI touchpoints and decision points
   - Consider privacy implications

2. **Implementation**
   - Use on-device ML whenever possible
   - Implement graceful fallbacks
   - Provide user control over AI features

3. **Testing**
   - Unit test AI service logic
   - Validate ML model performance
   - Test edge cases and failure modes

### Code Organization (Swift 6 / Xcode 26)

1. App (preferred for new code)
```
Sources/
└── App/
    └── Consolidated/
        ├── AIMixtapesApp.swift   // App entry
        ├── ContentView.swift     // Root UI
        ├── Services/             // App services (Audio, CoreData, etc.)
        ├── DI/                   // Dependency injection
        ├── Models/               // App models
        └── Resources/            // Assets, plists
```

2. Modules
```
Sources/
├── AudioKitEncorely/   // DSP (RMS/FFT), audio session
├── MCPClient/          // Socket.IO client & protocol
├── SharedTypes/        // Cross-module types
└── GlassUI/            // Reusable SwiftUI components
```

3. Local SPM Package
```
Sources/
└── Domain/             // Local package (tools 6.0)
```

### Best Practices

1. **AI Integration**
   - Use proper thread management for ML tasks
   - Implement progress indicators for AI operations
   - Cache ML results appropriately
   - Monitor memory usage

2. **Privacy & Security**
   - Never send sensitive data to external services
   - Use secure local storage for ML data
   - Implement proper data cleanup
   - Document data usage clearly

3. **Error Handling**
   - Provide meaningful error messages
   - Implement retry mechanisms
   - Log AI failures for analysis
   - Support graceful degradation

## 🔍 Code Review Guidelines

### AI Features
- [ ] Uses appropriate ML models
- [ ] Implements proper error handling
- [ ] Follows privacy guidelines
- [ ] Includes unit tests
- [ ] Documents AI decisions

### Performance
- [ ] Optimizes ML operations
- [ ] Manages memory properly
- [ ] Uses background processing
- [ ] Implements caching

### User Experience
- [ ] Provides feedback for AI operations
- [ ] Implements fallback options
- [ ] Respects user preferences
- [ ] Clear error messages

## 📚 Documentation Requirements

1. **AI Features**
   - Document ML model selection rationale
   - Explain AI decision-making process
   - List required permissions and why
   - Document privacy considerations

2. **Integration**
   - Provide setup instructions
   - Document dependencies
   - Include performance guidelines
   - List known limitations

3. **Testing**
   - Document test scenarios
   - Provide sample test data
   - Include performance benchmarks
   - List edge cases

## 🧪 Testing Standards

### Unit Tests
```swift
class AIServiceTests: XCTestCase {
    func testMoodDetection() {
        // Test mood detection accuracy
    }
    
    func testPersonalityAnalysis() {
        // Test personality predictions
    }
    
    func testRecommendations() {
        // Test recommendation quality
    }
}
```

### Integration Tests
- Test AI service interactions
- Validate data flow
- Check error handling
- Measure performance

### UI Tests
- Test AI feedback displays
- Verify loading states
- Check error messages
- Validate user controls

## 🎯 Pull Request Process

1. **Preparation**
   - Update documentation
   - Add/update tests
   - Check performance
   - Review privacy impact

2. **Review**
   - Code review by 2+ developers
   - AI implementation review
   - Performance review
   - Security review

3. **Merge**
   - Pass all tests
   - Meet performance criteria
   - Address review feedback
   - Update documentation

## 📈 Performance Guidelines

### ML Models
- Bundle size < 10MB per model
- Inference time < 100ms
- Memory usage < 50MB
- CPU usage < 30%

### Audio Processing
- Buffer size: 2048 samples
- Processing delay < 20ms
- Memory usage < 100MB
- Support background processing

### UI Performance
- AI feedback delay ≲ 16ms
- Smooth animations (60 fps)
- Memory usage < 150MB
- Battery impact < 10%

## Tooling
- Swift 6 / Xcode 26
- SwiftFormat / SwiftLint (respect repo configs)
- Pre-commit hooks: `bash scripts/install-githooks.sh`

See also: Docs/CODE_CONTEXT.md, Docs/ARCHITECTURE.md, Docs/DEV_NOTES.md
