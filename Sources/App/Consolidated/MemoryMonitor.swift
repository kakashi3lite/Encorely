import Foundation
import os.log

/// Singleton class for monitoring system memory usage
final class MemoryMonitor {
    // MARK: - Singleton

    static let shared = MemoryMonitor()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.aimixtapes", category: "MemoryMonitor")
    private let queue = DispatchQueue(label: "com.aimixtapes.memory.monitor")
    private let maxMemoryUsage: UInt64

    private var memorySamples: [Int] = []
    private let maxSamples = 20
    private var timer: Timer?

    private(set) var currentPressureLevel: MemoryPressureLevel = .low {
        didSet {
            if currentPressureLevel > oldValue {
                NotificationCenter.default.post(
                    name: .audioBufferPoolPressureChanged,
                    object: currentPressureLevel
                )
            }
        }
    }

    // MARK: - Initialization

    private init() {
        #if os(macOS)
            maxMemoryUsage = min(100 * 1024 * 1024, ProcessInfo.processInfo.physicalMemory / 20) // 5% of RAM or 100MB
        #else
            maxMemoryUsage = min(50 * 1024 * 1024, ProcessInfo.processInfo.physicalMemory / 40) // 2.5% of RAM or 50MB
        #endif

        setupMonitoring()
    }

    // MARK: - Public Methods

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryMetrics()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private Methods

    private func setupMonitoring() {
        #if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleMemoryWarning),
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        #endif

        startMonitoring()
    }

    private func updateMemoryMetrics() {
        let currentUsage = getCurrentMemoryUsage()

        queue.async { [weak self] in
            guard let self else { return }

            // Update samples
            if memorySamples.count >= maxSamples {
                memorySamples.removeFirst()
            }
            memorySamples.append(currentUsage)

            // Update pressure level
            let usage = Double(currentUsage) / Double(maxMemoryUsage)
            let newLevel = MemoryPressureLevel.from(memoryUsage: usage)

            if newLevel != currentPressureLevel {
                DispatchQueue.main.async {
                    self.currentPressureLevel = newLevel
                }
            }
        }
    }

    @objc private func handleMemoryWarning() {
        currentPressureLevel = .critical
        NotificationCenter.default.post(name: .audioBufferPoolEmergencyCleanup, object: nil)
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    var memoryTrend: MemoryTrend {
        guard memorySamples.count >= 2 else { return .stable }

        let changes = zip(memorySamples.dropLast(), memorySamples.dropFirst())
            .map { $1 - $0 }
        let avgChange = Double(changes.reduce(0, +)) / Double(changes.count)

        let threshold = Double(maxMemoryUsage) / 100 // 1% change threshold

        if avgChange > threshold {
            return .increasing
        } else if avgChange < -threshold {
            return .decreasing
        }
        return .stable
    }
}

enum MemoryTrend {
    case increasing
    case decreasing
    case stable
}
