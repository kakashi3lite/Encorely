// filepath: Sources/App/Consolidated/Perception/SoundEnvironmentAnalyzer.swift
import Combine
import Foundation

#if canImport(SoundAnalysis)
    import SoundAnalysis
#endif

/// Classifies ambient audio into coarse categories (silence/voice/energy cues)
final class SoundEnvironmentAnalyzer: ObservableObject {
    enum AmbientClass: String { case silence, speech, music, noise }

    private let subject = PassthroughSubject<AmbientClass, Never>()
    var publisher: AnyPublisher<AmbientClass, Never> { subject.eraseToAnyPublisher() }

    init() {}

    /// Provide external streaming classifications (stub-friendly)
    func update(_ ambient: AmbientClass) { subject.send(ambient) }
}
