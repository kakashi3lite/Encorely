// Thin forwarder extension into the canonical consolidated implementation.
// Keeps legacy Services/ path references compiling while avoiding duplicate types.

import Foundation

extension AudioProcessingConfiguration {
    /// Apply a named preset with optional persistence.
    /// - Parameters:
    ///   - preset: Optimization preset to apply.
    ///   - persist: Whether to save the configuration after applying.
    public func apply(_ preset: OptimizationPreset, persist: Bool = true) {
        self.optimizationPreset = preset
        if persist { self.saveConfiguration() }
    }

    /// Convenience to restore defaults and persist the change.
    public func restoreDefaultsAndSave() {
        self.resetToDefaults()
        self.saveConfiguration()
    }
}
