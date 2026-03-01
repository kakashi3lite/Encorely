<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/iOS-17%2B-000000?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/SwiftUI-100%25-blue?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/SwiftData-Persistence-purple?style=flat-square" />
  <img src="https://img.shields.io/badge/Tests-76%20passing-brightgreen?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" />
</p>

<h1 align="center">Encorely</h1>

<p align="center">
  <b>AI-powered mixtapes that adapt to your mood, personality, and sonic identity.</b>
</p>

<p align="center">
  <i>Built with Swift 6 &bull; SwiftUI &bull; SwiftData &bull; AudioKit &bull; MusicKit</i>
</p>

---

## What is Encorely?

Encorely is a native iOS app that generates personalized mixtapes using real-time audio analysis, mood detection, and a psychologically-grounded music preference model ([STOMP](https://gosling.psy.utexas.edu/scales-weve-developed/short-test-of-music-preferences-stomp/)). It learns your listening personality and evolves recommendations over time.

**Not another playlist generator.** Encorely builds a *Sonic Identity* -- a fingerprint of your musical taste across four psychological dimensions -- and uses it to curate mixtapes that actually match how you feel.

## Features

### Sonic Identity Onboarding
Three interactive mini-games replace the boring signup form:

- **Bubble Verse** -- Floating genre bubbles you tap to reveal your STOMP profile
- **Mood Tuner** -- A haptic rotary dial to set your energy baseline
- **Synesthesia Picker** -- Choose the color your music *sounds* like (drives the app theme)

### Mood-Aware Mixtapes
- Real-time mood detection from audio features (tempo, energy, valence, danceability)
- Time-of-day context awareness (morning calm vs. evening energy)
- Six mood states: Energetic, Relaxed, Happy, Melancholic, Focused, Angry

### Personality Engine
- Four music personality types: Explorer, Curator, Enthusiast, Analyzer
- Learns from your listening behavior (skips, completions, playlist creation)
- Adapts recommendation strategy per personality

### Audio Analysis & Visualization
- Live audio feature extraction via AudioKit (RMS, FFT, spectral analysis)
- Real-time spectrum visualizer and waveform display
- Canvas-based rendering for smooth 60fps performance

### Apple Music Integration
- MusicKit authorization and library access
- Search and add songs from Apple Music catalog
- Seamless playback via AVPlayer

## Architecture

```
100% SwiftUI  ·  MVVM + @Observable  ·  Swift 6 Strict Concurrency  ·  Zero UIKit
```

```
┌─────────────────────────────────────────────────────┐
│  Presentation (SwiftUI Views)                       │
│  ├── Onboarding  (Bubble, Dial, Synesthesia)        │
│  ├── Library     (Mixtapes, Cards, Detail)           │
│  ├── Generator   (Mood Selector, Generator)         │
│  ├── Player      (Full Player, Mini Player)         │
│  ├── Analysis    (Visualizer, Spectrum)             │
│  └── Insights    (Personality, Mood History)        │
├─────────────────────────────────────────────────────┤
│  ViewModels (@Observable)                           │
│  ├── LibraryViewModel, GeneratorViewModel           │
│  ├── PlayerViewModel, AnalysisViewModel             │
│  ├── InsightsViewModel, OnboardingViewModel         │
├─────────────────────────────────────────────────────┤
│  Domain (Core Logic)                                │
│  ├── MoodEngine          (rule-based detection)     │
│  ├── PersonalityEngine   (behavioral analysis)      │
│  ├── RecommendationEngine (scoring + ranking)       │
│  └── AudioAnalyzer       (FFT, feature extraction)  │
├─────────────────────────────────────────────────────┤
│  Services                                           │
│  ├── AudioPlaybackService (AVPlayer)                │
│  ├── MusicKitService      (Apple Music)             │
│  └── AudioSessionManager  (AVAudioSession)          │
├─────────────────────────────────────────────────────┤
│  Persistence (SwiftData @Model)                     │
│  ├── Song, Mixtape, UserProfile                     │
│  ├── MoodSnapshot, SonicProfile                     │
└─────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| UI Framework | SwiftUI (100%) | Declarative, no bridging overhead |
| State | `@Observable` macro | Simpler than Combine, native observation |
| Persistence | SwiftData | Modern replacement for Core Data, macro-driven |
| Concurrency | async/await + actors | Swift 6 strict concurrency, no data races |
| DI | Environment injection | No third-party containers needed |
| Audio | AudioKit + SoundpipeAudioKit | Industry-standard DSP for iOS |
| Layout | Custom `Layout` protocol | Performance over GeometryReader for complex layouts |
| Project Gen | XcodeGen | Reproducible `.xcodeproj` from `project.yml` |

## Getting Started

### Prerequisites

- **Xcode 16+** (Swift 6 toolchain)
- **iOS 17.0+** simulator or device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & Run

```bash
# Clone
git clone https://github.com/kakashi3lite/Encorely.git
cd Encorely

# Generate Xcode project from project.yml
xcodegen generate

# Open in Xcode
open Encorely.xcodeproj

# Or build from CLI
xcodebuild -project Encorely.xcodeproj \
  -scheme Encorely \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### Run Tests

```bash
xcodebuild -project Encorely.xcodeproj \
  -scheme Encorely \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

**76 tests across 10 suites** covering:

| Suite | Tests | What It Covers |
|-------|-------|----------------|
| AudioAnalyzerTests | 4 | FFT extraction, energy detection, spectrum data |
| ModelTests | 14 | SwiftData models, Codable roundtrips, relationships |
| MoodEngineTests | 6 | All 6 mood states, confidence, history tracking |
| PersonalityEngineTests | 7 | Personality inference, interaction recording, reset |
| RecommendationEngineTests | 8 | Scoring, ranking, filtering, cache invalidation |
| ViewModelTests | 8 | Sorting, formatting, mood frequency computation |
| STOMPGenre | 7 | 14-genre mapping, dimension coverage, icons |
| SonicProfile | 3 | Default values, dominant dimension, hex roundtrip |
| OnboardingViewModel | 10 | Toggle, scoring, navigation, finalization gating |
| Color+Hex | 2 | Hex parsing, 6/8-digit formats |

## Project Structure

```
Encorely/
├── App/                          # Entry point + AppState
│   ├── EncorelyApp.swift         # @main, RootGateView (onboarding vs main)
│   └── AppEnvironment.swift      # Custom environment keys
├── Models/                       # SwiftData @Model definitions
│   ├── Song.swift
│   ├── Mixtape.swift
│   ├── UserProfile.swift
│   ├── MoodSnapshot.swift
│   ├── SonicProfile.swift        # STOMP dimensions + synesthesia color
│   └── SharedTypes.swift         # Mood, PersonalityType, AudioFeatures
├── Domain/                       # Core business logic
│   ├── MoodEngine.swift          # Rule-based mood detection
│   ├── PersonalityEngine.swift   # Behavioral personality analysis
│   ├── RecommendationEngine.swift
│   └── AudioAnalyzer.swift       # FFT + feature extraction
├── Services/                     # System integrations
│   ├── AudioPlaybackService.swift
│   ├── MusicKitService.swift
│   └── AudioSessionManager.swift
├── ViewModels/                   # @Observable view models
├── Views/
│   ├── Onboarding/               # Sonic Identity flow
│   │   ├── OnboardingContainerView.swift  # 3-layer ZStack architecture
│   │   ├── GenreBubbleView.swift          # STOMP genre bubbles
│   │   ├── MoodDialView.swift             # Haptic energy knob
│   │   └── SynesthesiaView.swift          # Color aura picker
│   ├── Library/                  # Mixtape collection
│   ├── Generator/                # Mixtape creation
│   ├── Player/                   # Playback UI
│   ├── Analysis/                 # Audio visualization
│   ├── Insights/                 # Personality + mood history
│   ├── Profile/                  # User settings
│   ├── Navigation/               # TabView + routing
│   └── Shared/                   # Empty state, error, loading
├── Extensions/                   # Color+Mood, View+Accessibility
└── Resources/                    # Assets, Info.plist, entitlements

EncorelyTests/                    # 76 unit tests across 10 suites
project.yml                       # XcodeGen specification
Package.swift                     # SPM dependency manifest
```

## The STOMP Model

Encorely's genre profiling is based on the **Short Test of Music Preferences** (Rentfrow & Gosling, UT Austin). It maps 14 music genres to four psychological dimensions:

| Dimension | Genres | Personality Correlation |
|-----------|--------|------------------------|
| **Reflective & Complex** | Classical, Jazz, Blues, Folk | Openness to experience |
| **Intense & Rebellious** | Rock, Alternative, Heavy Metal, Punk | Disagreeableness |
| **Upbeat & Conventional** | Pop, Country, Religious, Soundtracks | Extraversion, agreeableness |
| **Energetic & Rhythmic** | Rap/Hip-Hop, Electronica | Extraversion |

Users build their Sonic Identity during onboarding by selecting genres they resonate with. Scores are computed as `(selected in dimension) / (total in dimension)` and persisted via SwiftData.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI (iOS 17+, no UIKit) |
| Persistence | SwiftData (`@Model`) |
| Audio DSP | AudioKit 5.6, SoundpipeAudioKit 5.7 |
| Music | MusicKit (Apple Music) |
| Playback | AVPlayer, AVAudioSession |
| Project | XcodeGen (`project.yml`) |
| Testing | Swift Testing framework |
| CI | GitHub Actions |

## Contributing

1. Fork this repo
2. Create your branch: `git checkout -b feature/your-feature`
3. Follow the existing patterns (MVVM, `@Observable`, SwiftData)
4. Write tests for new logic
5. Open a PR

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built by <a href="https://github.com/kakashi3lite">@kakashi3lite</a></sub>
</p>
