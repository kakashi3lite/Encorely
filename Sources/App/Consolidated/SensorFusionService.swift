import Foundation
import Combine
import Domain

final class SensorFusionService: ObservableObject {
    struct Snapshot: Identifiable {
        let id = UUID()
        let date: Date
        let heartRate: Int
        let energyLevel: Double
        let stressScore: Double
        let focusScore: Double
    }

    @Published private(set) var latest: Snapshot? = nil
    private var timerCancellable: AnyCancellable?

    init(autostart: Bool = true) { if autostart { startSimulation() } }

    func startSimulation() {
        guard timerCancellable == nil else { return }
        timerCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.emitSimulatedSnapshot() }
        emitSimulatedSnapshot()
    }

    func stop() { timerCancellable?.cancel(); timerCancellable = nil }

    private func emitSimulatedSnapshot() {
        let hr = Int.random(in: 58...108)
        let energy = min(1, max(0, (Double(hr) - 50) / 70))
        let stress = Double.random(in: 0.1...0.7)
        let focus = Double.random(in: 0.3...0.9)
        latest = Snapshot(date: Date(), heartRate: hr, energyLevel: energy, stressScore: stress, focusScore: focus)
    }
}

extension AIIntegrationService {
    func ingest(sensorSnapshot: SensorFusionService.Snapshot) {
        let energy = sensorSnapshot.energyLevel
        let stress = sensorSnapshot.stressScore
        let focus = sensorSnapshot.focusScore
        guard moodEngine.adaptToContext else { return }
        if energy > 0.65 && stress < 0.4 {
            moodEngine.registerExternalMoodHint(.energetic, weight: Float(0.2 * energy))
        } else if focus > 0.6 && stress < 0.5 {
            moodEngine.registerExternalMoodHint(.focused, weight: Float(0.15 * focus))
        } else if stress > 0.6 {
            moodEngine.registerExternalMoodHint(.relaxed, weight: 0.2)
        }
    }
}
