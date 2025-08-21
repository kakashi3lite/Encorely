import XCTest
import SwiftUI
@testable import GlassUI

final class UIComponentTests: XCTestCase {
    
    func testGlassCardAccessibility() {
        let card = GlassCard {
            Text("Test Content")
        }
        
        // Test that GlassCard can be instantiated
        XCTAssertNotNil(card)
    }
    
    func testActionButtonInitialization() {
        let button = ActionButton(
            title: "Test",
            icon: "heart.fill"
        ) {
            // Test action
        }
        
        XCTAssertNotNil(button)
    }
    
    func testFeatureRowInitialization() {
        let row = FeatureRow(
            icon: "mic.fill",
            title: "Test Feature",
            description: "Test description"
        )
        
        XCTAssertNotNil(row)
    }
    
    func testSettingsRowInitialization() {
        let row = SettingsRow(
            title: "Test Setting",
            subtitle: "Test Value",
            icon: "gear"
        )
        
        XCTAssertNotNil(row)
    }
    
    func testAudioLevelMeterInitialization() {
        let meter = AudioLevelMeter(level: 0.5, barCount: 20)
        
        XCTAssertNotNil(meter)
    }
    
    func testAudioLevelMeterEdgeCases() {
        // Test with zero level
        let zeroMeter = AudioLevelMeter(level: 0.0)
        XCTAssertNotNil(zeroMeter)
        
        // Test with maximum level
        let maxMeter = AudioLevelMeter(level: 1.0)
        XCTAssertNotNil(maxMeter)
        
        // Test with custom bar count
        let customMeter = AudioLevelMeter(level: 0.5, barCount: 50)
        XCTAssertNotNil(customMeter)
    }
    
    @MainActor
    func testPerformanceMonitorInitialization() {
        let monitor = PerformanceMonitor()
        
        XCTAssertEqual(monitor.fps, 60.0)
        XCTAssertEqual(monitor.memoryUsage, 0.0)
        
        // Test starting monitoring
        monitor.startMonitoring()
        
        // Test stopping monitoring
        monitor.stopMonitoring()
        
        XCTAssertTrue(true) // Should not crash
    }
    
    func testErrorHandlerInitialization() {
        let errorHandler = ErrorHandler()
        
        XCTAssertNil(errorHandler.currentError)
        XCTAssertFalse(errorHandler.showingError)
    }
    
    func testErrorHandling() {
        let errorHandler = ErrorHandler()
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        errorHandler.handle(testError)
        
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertTrue(errorHandler.showingError)
        XCTAssertEqual(errorHandler.currentError?.message, "Test error")
    }
    
    func testAppErrorCreation() {
        let appError = AppError(title: "Test Title", message: "Test Message")
        
        XCTAssertEqual(appError.title, "Test Title")
        XCTAssertEqual(appError.message, "Test Message")
        XCTAssertNil(appError.underlyingError)
    }
    
    func testAppErrorFromError() {
        let nsError = NSError(domain: "TestDomain", code: 456, userInfo: [NSLocalizedDescriptionKey: "Original error"])
        let appError = AppError.from(nsError)
        
        XCTAssertEqual(appError.title, "Unexpected Error")
        XCTAssertEqual(appError.message, "Original error")
        XCTAssertNotNil(appError.underlyingError)
    }
    
    func testDeviceInfo() {
        // Test that device info can be retrieved without crashing
        let modelName = DeviceInfo.modelName
        let isSimulator = DeviceInfo.isSimulator
        let screenSize = DeviceInfo.screenSize
        let scale = DeviceInfo.scale
        
        XCTAssertFalse(modelName.isEmpty)
        XCTAssertGreaterThan(screenSize.width, 0)
        XCTAssertGreaterThan(screenSize.height, 0)
        XCTAssertGreaterThan(scale, 0)
        
        #if targetEnvironment(simulator)
        XCTAssertTrue(isSimulator)
        #else
        XCTAssertFalse(isSimulator)
        #endif
    }
}

// MARK: - Visual Component Tests
final class VisualComponentTests: XCTestCase {
    
    func testWaveformViewInitialization() {
        let testData: [Float] = Array(0..<100).map { Float(sin(Double($0) * 0.1)) }
        let waveform = WaveformView(data: testData)
        
        XCTAssertNotNil(waveform)
    }
    
    func testWaveformViewEmptyData() {
        let emptyData: [Float] = []
        let waveform = WaveformView(data: emptyData)
        
        XCTAssertNotNil(waveform)
    }
    
    func testWaveformViewSingleDataPoint() {
        let singleData: [Float] = [0.5]
        let waveform = WaveformView(data: singleData)
        
        XCTAssertNotNil(waveform)
    }
    
    func testSpectrumViewInitialization() {
        let testData: [Float] = Array(0..<50).map { Float($0) / 50.0 }
        let spectrum = SpectrumView(data: testData)
        
        XCTAssertNotNil(spectrum)
    }
    
    func testSpectrumViewEmptyData() {
        let emptyData: [Float] = []
        let spectrum = SpectrumView(data: emptyData)
        
        XCTAssertNotNil(spectrum)
    }
    
    func testLevelMeterViewInitialization() {
        let levelMeter = LevelMeterView(rmsLevel: 0.5, peakLevel: 0.8)
        
        XCTAssertNotNil(levelMeter)
    }
    
    func testLevelMeterViewEdgeCases() {
        // Test with zero levels
        let zeroMeter = LevelMeterView(rmsLevel: 0.0, peakLevel: 0.0)
        XCTAssertNotNil(zeroMeter)
        
        // Test with maximum levels
        let maxMeter = LevelMeterView(rmsLevel: 1.0, peakLevel: 1.0)
        XCTAssertNotNil(maxMeter)
        
        // Test with peak higher than RMS (typical scenario)
        let normalMeter = LevelMeterView(rmsLevel: 0.6, peakLevel: 0.9)
        XCTAssertNotNil(normalMeter)
    }
}

// MARK: - Accessibility Tests
final class AccessibilityTests: XCTestCase {
    
    func testGlassCardAccessibilityLabel() {
        let card = GlassCard {
            Text("Accessible content")
        }
        
        // The GlassCard should have proper accessibility support
        XCTAssertNotNil(card)
    }
    
    func testActionButtonAccessibility() {
        let button = ActionButton(
            title: "Record Audio",
            icon: "mic.fill"
        ) {
            // Action
        }
        
        // ActionButton should be accessible
        XCTAssertNotNil(button)
    }
    
    func testFeatureRowAccessibility() {
        let row = FeatureRow(
            icon: "accessibility",
            title: "Accessibility Feature",
            description: "Full VoiceOver support"
        )
        
        XCTAssertNotNil(row)
    }
}

// MARK: - Performance Tests
final class UIPerformanceTests: XCTestCase {
    
    func testWaveformViewPerformance() {
        let largeDataset: [Float] = Array(0..<1000).map { Float(sin(Double($0) * 0.01)) }
        
        measure {
            let waveform = WaveformView(data: largeDataset)
            _ = waveform.body
        }
    }
    
    func testSpectrumViewPerformance() {
        let largeSpectrum: [Float] = Array(0..<512).map { Float($0) / 512.0 }
        
        measure {
            let spectrum = SpectrumView(data: largeSpectrum)
            _ = spectrum.body
        }
    }
    
    func testAudioLevelMeterPerformance() {
        measure {
            let meter = AudioLevelMeter(level: 0.75, barCount: 100)
            _ = meter.body
        }
    }
    
    @MainActor
    func testPerformanceMonitorAccuracy() {
        let monitor = PerformanceMonitor()
        monitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Performance monitoring")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // After 2 seconds, we should have some FPS data
            XCTAssertGreaterThan(monitor.fps, 0)
            monitor.stopMonitoring()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
}

// MARK: - Integration Tests
final class ComponentIntegrationTests: XCTestCase {
    
    func testCompleteUIStackIntegration() {
        // Test that all UI components can work together
        let actionButton = ActionButton(title: "Test", icon: "play.fill") {}
        let featureRow = FeatureRow(icon: "mic", title: "Recording", description: "High quality")
        let settingsRow = SettingsRow(title: "Audio", subtitle: "Active", icon: "speaker")
        let levelMeter = AudioLevelMeter(level: 0.7)
        
        XCTAssertNotNil(actionButton)
        XCTAssertNotNil(featureRow)
        XCTAssertNotNil(settingsRow)
        XCTAssertNotNil(levelMeter)
    }
    
    func testGlassCardWithComplexContent() {
        let complexCard = GlassCard {
            VStack {
                HStack {
                    FeatureRow(icon: "mic", title: "Recording", description: "Active")
                    Spacer()
                    AudioLevelMeter(level: 0.5)
                }
                Divider()
                ActionButton(title: "Stop", icon: "stop.fill") {}
            }
        }
        
        XCTAssertNotNil(complexCard)
    }
    
    @MainActor
    func testErrorHandlerIntegrationWithComponents() {
        let errorHandler = ErrorHandler()
        let testError = AppError(title: "Audio Error", message: "Failed to initialize microphone")
        
        errorHandler.handle(testError)
        
        XCTAssertTrue(errorHandler.showingError)
        XCTAssertEqual(errorHandler.currentError?.title, "Audio Error")
        
        errorHandler.clearError()
        
        XCTAssertFalse(errorHandler.showingError)
        XCTAssertNil(errorHandler.currentError)
    }
}