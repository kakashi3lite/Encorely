# AI-Mixtapes

AI-powered iOS app that creates personalized mixtapes using mood analysis and AI recommendations. Built with SwiftUI and CoreData, featuring an intuitive interface and smart playlist generation.

## Features

### Core AI Features
- 🎵 Mood-based playlist generation
- 🤖 AI-powered song analysis
- 📊 Audio feature extraction
- 🎨 Dynamic UI that adapts to mood
- 📈 Personal music insights

### Technical Features
- SwiftUI-based modern UI
- CoreData persistence
- AudioKit integration
- Mood analysis engine
- Real-time audio visualization

## Requirements
- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/kakashi3lite/AI-Mixtapes.git
cd AI-Mixtapes
```

2. Open the project in Xcode:
```bash
xed .
```

3. Build and run the project (⌘R)

## Architecture

### Core Components
- **Models**: CoreData models for mixtapes and songs
- **Views**: SwiftUI views for user interface
- **Services**: Audio analysis and AI recommendation engines
- **Managers**: CoreData and audio session management

### Data Models
- `MixTape`: Stores playlist metadata and mood information
- `Song`: Manages individual song data and audio features
- `AudioFeatures`: Captures audio analysis results

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Copyright © 2025 kakashi3lite. All rights reserved.