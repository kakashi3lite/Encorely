# AI-Mixtapes

AI-powered music playlist generator with mood detection and personality analysis.

[![Tests](https://github.com/username/AI-Mixtapes/actions/workflows/tests.yml/badge.svg)](https://github.com/username/AI-Mixtapes/actions/workflows/tests.yml)
[![Documentation](https://github.com/username/AI-Mixtapes/actions/workflows/documentation.yml/badge.svg)](https://username.github.io/AI-Mixtapes/documentation/aimixtapes/)
[![codecov](https://codecov.io/gh/username/AI-Mixtapes/branch/main/graph/badge.svg)](https://codecov.io/gh/username/AI-Mixtapes)
[![Swift Version](https://img.shields.io/badge/swift-5.5-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B%20%7C%20macOS%2012.0%2B-blue.svg)](https://developer.apple.com)

## Features

- 🎵 AI-powered playlist generation
- 🎨 Mood-based music analysis
- 🧠 Personality-driven recommendations
- 📊 Advanced audio processing
- 🎯 SwiftUI interface
- 🔊 Siri integration

### Performance Monitoring

The app includes comprehensive performance monitoring:
- Real-time performance tracking
- Memory usage optimization
- Automated cleanup on memory warnings
- Performance metrics logging

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/username/AI-Mixtapes.git", from: "1.0.0")
]
```

### Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.5+
- Xcode 13.0+

## Quick Start

```swift
import AIMixtapes

// Initialize the framework
try AIMixtapes.initialize()

// Create a mood-based playlist
let playlist = try await MoodEngine.shared.createPlaylist(
    mood: .happy,
    duration: .minutes(30)
)

// Analyze audio
let features = try await AudioAnalysisService.shared.analyzeAudio(
    from: audioURL
)
```

## Documentation

- [API Reference](https://username.github.io/AI-Mixtapes/documentation/aimixtapes/)
- [Getting Started Guide](docs/getting-started.md)
- [Architecture Overview](docs/architecture.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## Project Structure

```
AI-Mixtapes/
├── Sources/          # Main source code
├── Tests/           # Test suite
├── Resources/       # Project resources
└── docs/           # Documentation
```

## Development

1. Clone the repository
2. Run `swift build`
3. Run `swift test`
4. See [Contributing](CONTRIBUTING.md)

### Mac Deployment

To build for macOS:
1. Open the project in Xcode
2. Select the macOS destination
3. Run the "Build for Mac" task:
   ```bash
   xcodebuild -scheme AIMixtapes -configuration Release -destination "platform=macOS"
   ```

## Testing

```bash
# Run all tests
swift test

# Run specific tests
swift test --filter AITests

# Generate coverage report
swift test --enable-code-coverage
```

### Performance Testing

Run the performance test suite:
```bash
xcodebuild -scheme AIMixtapes -destination "platform=macOS" test ONLY_TESTING=AIMixtapesTests/PerformanceTests
```

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Swift System](https://github.com/apple/swift-system)
- [Swift Collections](https://github.com/apple/swift-collections)
- [Swift Algorithms](https://github.com/apple/swift-algorithms)