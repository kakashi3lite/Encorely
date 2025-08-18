// filepath: Sources/App/Consolidated/Perception/FaceAffectAnalyzer.swift
import Combine
import Foundation

#if canImport(ARKit)
    import ARKit
#endif
#if canImport(Vision)
    import Vision
#endif

/// Lightweight mapper from facial action units/blend shapes to (valence, arousal)
enum FaceAffectMapper {
    /// Map normalized blend shape magnitudes into valence/arousal in 0.0...1.0
    static func map(blendShapes: [String: Double]) -> (valence: Double, arousal: Double) {
        let smile = blendShapes["mouthSmile_L"] ?? 0 + (blendShapes["mouthSmile_R"] ?? 0)
        let browDown = (blendShapes["browDown_L"] ?? 0 + (blendShapes["browDown_R"] ?? 0)) / 2
        let jawOpen = blendShapes["jawOpen"] ?? 0
        let eyeSquint = (blendShapes["eyeSquint_L"] ?? 0 + (blendShapes["eyeSquint_R"] ?? 0)) / 2
        let valence = max(0.0, min(1.0, 0.6 * smile - 0.3 * browDown + 0.1))
        let arousal = max(0.0, min(1.0, 0.5 * jawOpen + 0.3 * eyeSquint + 0.1))
        return (valence, arousal)
    }
}

/// Emits face-driven affect estimates; ARKit/Vision usage is optional
final class FaceAffectAnalyzer: ObservableObject {
    private let subject = PassthroughSubject<(valence: Double, arousal: Double), Never>()
    var publisher: AnyPublisher<(valence: Double, arousal: Double), Never> { subject.eraseToAnyPublisher() }

    init() {}

    /// Provide external updates (e.g., from ARFaceAnchor/VN observations) as blend shape magnitudes (0..1)
    func update(blendShapes: [String: Double]) {
        subject.send(FaceAffectMapper.map(blendShapes: blendShapes))
    }
}
