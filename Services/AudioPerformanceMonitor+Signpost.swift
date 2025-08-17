import Foundation
import os.signpost

// Global signposter used for performance tracing
private let _aim_signposter = OSSignposter()

extension AudioPerformanceMonitor {
    /// Begins a signposted interval for a labeled audio processing section
    /// - Parameter name: A static string identifying the section (e.g., "FFT", "MixerStep")
    /// - Returns: The signpost ID to pass to endSignpost
    @discardableResult
    func beginSignpost(_ name: StaticString) -> OSSignpostID {
        let id = _aim_signposter.makeSignpostID()
        _aim_signposter.beginInterval(name, id: id)
        return id
    }

    /// Ends a previously started signposted interval
    /// - Parameters:
    ///   - name: The same label used for beginSignpost
    ///   - id: The signpost ID returned from beginSignpost
    func endSignpost(_ name: StaticString, _ id: OSSignpostID) {
        _aim_signposter.endInterval(name, id: id)
    }

    /// Emits a discrete event signpost with an optional message
    /// - Parameters:
    ///   - name: Event label
    ///   - message: Optional message string
    func eventSignpost(_ name: StaticString, message: String? = nil) {
        if let message {
            _aim_signposter.emitEvent(name, "\(message)")
        } else {
            _aim_signposter.emitEvent(name)
        }
    }
}
