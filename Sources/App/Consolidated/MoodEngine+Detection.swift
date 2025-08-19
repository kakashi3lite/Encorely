//  MoodEngine+Detection.swift
//  Feature scoring & detection logic extracted from monolithic engine.

import Foundation

extension MoodEngine {
    func processFeaturesUpdate(_ features: AudioFeatures) {
        guard detectionState == .active else { return }
        let result = detectMoodFromFeatures(features)
        updateMood(result.mood, confidence: result.confidence)
    }

    func detectMoodFromFeatures(_ features: AudioFeatures) -> (mood: Mood, confidence: Float) {
        var scores: [(Mood, Float)] = [
            (.energetic, calculateEnergeticScore(features)),
            (.relaxed, calculateRelaxedScore(features)),
            (.happy, calculateHappyScore(features)),
            (.melancholic, calculateMelancholicScore(features)),
            (.focused, calculateFocusedScore(features)),
        ]
        scores.sort { $0.1 > $1.1 }
        guard let top = scores.first else { return (.neutral, 0.5) }
        let second = scores.dropFirst().first?.1 ?? 0
        let margin = max(0, top.1 - second)
        return (top.0, min(1.0, 0.5 + margin))
    }

    func extractMoodFromAudioAnalysis(_ f: AudioFeatures) -> (mood: Mood, confidence: Float) {
        var conf: [Mood: Float] = Dictionary(uniqueKeysWithValues: Mood.allCases.map { ($0, 0) })
        if let energy = f.energy {
            if energy > 0.8 { conf[.energetic]! += 0.4
                conf[.happy]! += 0.2
                conf[.angry]! += 0.2
            } else if energy > 0.5 { conf[.happy]! += 0.3
                conf[.focused]! += 0.2
            } else { conf[.relaxed]! += 0.3
                conf[.melancholic]! += 0.2
            }
        }
        if let valence = f.valence {
            if valence > 0.8 { conf[.happy]! += 0.4
                conf[.romantic]! += 0.2
            } else if valence > 0.5 { conf[.focused]! += 0.2
                conf[.energetic]! += 0.1
            } else { conf[.melancholic]! += 0.3
                conf[.angry]! += 0.2
            }
        }
        if let tempo = f.tempo {
            if tempo > 120 { conf[.energetic]! += 0.3
                conf[.focused]! += 0.2
            } else if tempo > 90 { conf[.happy]! += 0.2
                conf[.romantic]! += 0.1
            } else { conf[.relaxed]! += 0.3
                conf[.melancholic]! += 0.2
                conf[.romantic]! += 0.1
            }
        }
        if let mode = f.mode { // key unused
            if mode > 0.5 { conf[.happy]! += 0.2
                conf[.energetic]! += 0.1
            } else { conf[.melancholic]! += 0.2
                conf[.relaxed]! += 0.1
            }
        }
        if let spectral = f.spectralFeatures {
            if let b = spectral.brightness, b > 0.6 { conf[.energetic]! += 0.2
                conf[.focused]! += 0.2
            }
            if let r = spectral.roughness, r > 0.7 { conf[.angry]! += 0.3 }
        }
        if adaptToContext { adjustForTimeOfDay(moodConfidence: &conf) }
        guard let (m, c) = conf.max(by: { $0.value < $1.value }) else { return (.neutral, 0.5) }
        return (m, c)
    }

    func adjustForTimeOfDay(moodConfidence: inout [Mood: Float]) {
        switch getTimeOfDayContext() {
        case .morning: moodConfidence[.energetic]! += 0.1
            moodConfidence[.focused]! += 0.1
        case .afternoon: moodConfidence[.happy]! += 0.1
            moodConfidence[.focused]! += 0.1
        case .evening: moodConfidence[.relaxed]! += 0.1
            moodConfidence[.romantic]! += 0.1
        case .night: moodConfidence[.melancholic]! += 0.1
            moodConfidence[.relaxed]! += 0.1
        }
    }

    func getTimeOfDayContext() -> TimeContext {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour { case 5 ..< 12: return .morning
        case 12 ..< 17: return .afternoon
        case 17 ..< 22: return .evening
        default: return .night }
    }

    private func calculateEnergeticScore(_ f: AudioFeatures) -> Float { min(
        1,
        f.energy * 0.4 + (f.tempo / 180) * 0.3 + f.danceability * 0.3
    ) }
    private func calculateRelaxedScore(_ f: AudioFeatures) -> Float { min(
        1,
        (1 - f.energy) * 0.4 + f.acousticness * 0.3 + (1 - f.tempo / 120) * 0.3
    ) }
    private func calculateHappyScore(_ f: AudioFeatures) -> Float { min(
        1,
        f.valence * 0.4 + f.energy * 0.3 + f.danceability * 0.3
    ) }
    private func calculateMelancholicScore(_ f: AudioFeatures) -> Float { min(
        1,
        (1 - f.valence) * 0.4 + (1 - f.energy) * 0.3 + f.acousticness * 0.3
    ) }
    private func calculateFocusedScore(_ f: AudioFeatures) -> Float { min(
        1,
        f.instrumentalness * 0.4 + (1 - f.speechiness) * 0.3 + (0.5 - abs(0.5 - f.energy)) * 0.3
    ) }
}
