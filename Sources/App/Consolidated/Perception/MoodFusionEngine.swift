// filepath: Sources/App/Consolidated/Perception/MoodFusionEngine.swift
import Combine
import Foundation

/// Fuses affect (face) and ambient (audio) with time context into a MoodState
final class MoodFusionEngine: ObservableObject {
    struct MoodState: Equatable { let valence: Double
        let arousal: Double
        let source: String
    }

    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<MoodState, Never>(.init(valence: 0.5, arousal: 0.5, source: "init"))
    var publisher: AnyPublisher<MoodState, Never> { subject.eraseToAnyPublisher() }

    init(face: FaceAffectAnalyzer, sound: SoundEnvironmentAnalyzer) {
        face.publisher
            .combineLatest(sound.publisher.prepend(.silence))
            .map { affect, ambient -> MoodState in
                let ambienceBoost: Double = (ambient == .music ? 0.05 : ambient == .speech ? -0.05 : 0.0)
                let val = max(0, min(1, affect.valence + ambienceBoost))
                let aro = max(0, min(1, affect.arousal + (ambient == .noise ? 0.05 : 0.0)))
                return .init(valence: val, arousal: aro, source: "fusion")
            }
            .sink { [weak self] in self?.subject.send($0) }
            .store(in: &cancellables)
    }
}
