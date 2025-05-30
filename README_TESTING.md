# Testing Guide for AI-Mixtapes

This document outlines the testing infrastructure and test suites available in the AI-Mixtapes project.

## Test Suite Structure

The project includes comprehensive test suites for various components:

### 1. Accessibility Tests (ISSUE-009)

The `AccessibilityServiceTests` suite validates all accessibility features:

- **Label and Description Tests**
  - Mood accessibility labels
  - Personality type descriptions
  - Dynamic content updates
  - Screen reader compatibility

- **Value and State Tests**
  - Audio progress values
  - Playback state descriptions
  - Control states
  - Error notifications

- **Interaction Tests**
  - VoiceOver gestures
  - Dynamic type scaling
  - High contrast adaptations
  - Motion reduction preferences

- **Performance Tests**
  - Label generation speed
  - Dynamic updates performance
  - Memory usage monitoring

### 2. SiriKit Intent Tests (ISSUE-010)

The `OptimizedSiriIntentServiceTests` suite covers intent handling optimization:

- **Performance Tests**
  - Intent handling speed < 500ms
  - Search operations < 300ms
  - Cached responses < 100ms

- **Caching Tests**
  - Mood caching
  - Mixtape result caching
  - Response caching
  - Cache invalidation

- **Concurrent Operation Tests**
  - Multiple simultaneous requests
  - Memory usage under load
  - Thread safety validation

- **Error Handling**
  - Invalid intent handling
  - Core Data error recovery
  - Network timeout handling

## Running Tests

### Prerequisites

- Xcode 14.0 or later
- macOS 13.0 or later for development
- iOS 16.0 or later for device testing

### Command Line Testing

```bash
# Run all tests
xcodebuild test -scheme AIMixtapes -destination "platform=macOS"

# Run only accessibility tests
xcodebuild test -scheme AIMixtapes -destination "platform=macOS" -only-testing "AIMixtapesTests/AccessibilityServiceTests"

# Run only SiriKit tests
xcodebuild test -scheme AIMixtapes -destination "platform=macOS" -only-testing "AIMixtapesTests/OptimizedSiriIntentServiceTests"
```

### VS Code Tasks

Use the integrated VS Code tasks for testing:

1. `Run Performance Tests` - Executes performance-critical test suites
2. `Clean Build` - Cleans the build directory before testing
3. `Build for Mac` - Builds and runs tests for macOS

## Performance Benchmarks

### Accessibility Performance Targets

- Label generation: < 5ms
- Dynamic updates: < 16ms (60 FPS)
- Memory impact: < 5MB overhead

### SiriKit Performance Targets

- Intent handling: < 500ms
- Cached responses: < 100ms
- Memory usage: < 20MB under load

## Test Coverage

The test suites aim for:

- 100% coverage of accessibility features
- 100% coverage of SiriKit intent handling
- 95% coverage of error cases
- 90% coverage of edge cases

## Continuous Integration

Tests are automatically run on:

- Every push to main branch
- Pull request creation
- Daily scheduled builds

## Contributing

When adding new features:

1. Create corresponding test files
2. Maintain or improve coverage ratios
3. Add performance benchmarks
4. Document test cases

## Known Issues

- Accessibility tests may be flaky on CI due to system permissions
- SiriKit tests require proper entitlements in CI environment

## Future Improvements

- Add stress testing for concurrent operations
- Implement snapshot testing for UI components
- Add network condition simulation
- Enhance error injection testing
