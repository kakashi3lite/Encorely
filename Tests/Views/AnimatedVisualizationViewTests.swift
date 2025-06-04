import XCTest
import ViewInspector
import SwiftUI
@testable import App

extension AnimatedVisualizationView: Inspectable {}

final class AnimatedVisualizationViewTests: XCTestCase {
    func testInitialization() throws {
        let audioData = Array(repeating: Float(0.5), count: 40)
        let mood = Mood.energetic
        let view = AnimatedVisualizationView(audioData: audioData, mood: mood, sensitivity: 1.0)
        
        XCTAssertNoThrow(try view.inspect())
        
        let spriteView = try view.inspect().geometryReader().zStack().spriteView(0)
        XCTAssertNotNil(spriteView)
        
        let waveform = try view.inspect().geometryReader().zStack().view(1)
        XCTAssertNotNil(waveform)
        
        let moodIndicator = try view.inspect().geometryReader().zStack().view(2)
        XCTAssertNotNil(moodIndicator)
    }
    
    func testMoodColorChanges() throws {
        // Test different moods
        let moods: [Mood] = [.calm, .energetic, .happy, .melancholic]
        let audioData = Array(repeating: Float(0.5), count: 40)
        
        for mood in moods {
            let view = AnimatedVisualizationView(audioData: audioData, mood: mood, sensitivity: 1.0)
            let moodIndicator = try view.inspect().geometryReader().zStack().view(2)
            
            // Verify mood indicator exists for each mood
            XCTAssertNotNil(moodIndicator)
        }
    }
    
    func testSensitivityParameter() throws {
        let audioData = Array(repeating: Float(0.5), count: 40)
        let mood = Mood.energetic
        let sensitivities = [0.1, 1.0, 2.0]
        
        for sensitivity in sensitivities {
            let view = AnimatedVisualizationView(audioData: audioData, mood: mood, sensitivity: sensitivity)
            XCTAssertNoThrow(try view.inspect())
        }
    }
    
    func testAudioDataUpdates() throws {
        let initialData = Array(repeating: Float(0.5), count: 40)
        let mood = Mood.energetic
        let view = AnimatedVisualizationView(audioData: initialData, mood: mood, sensitivity: 1.0)
        
        XCTAssertNoThrow(try view.inspect())
        
        // Test with different audio data
        let updatedData = Array(repeating: Float(0.8), count: 40)
        let updatedView = AnimatedVisualizationView(audioData: updatedData, mood: mood, sensitivity: 1.0)
        
        XCTAssertNoThrow(try updatedView.inspect())
    }
    
    func testParticleSceneSetup() throws {
        let audioData = Array(repeating: Float(0.5), count: 40)
        let mood = Mood.energetic
        let view = AnimatedVisualizationView(audioData: audioData, mood: mood, sensitivity: 1.0)
        
        let spriteView = try view.inspect().geometryReader().zStack().spriteView(0)
        XCTAssertNotNil(spriteView)
        
        // Test scene size matches view size
        let size = CGSize(width: 300, height: 300)
        let scene = ParticleScene(size: size, mood: mood)
        XCTAssertEqual(scene.size, size)
    }
    
    // Performance Tests
    func testVisualizationPerformance() {
        let audioData = Array(repeating: Float(0.5), count: 40)
        let mood = Mood.energetic
        
        measure {
            let view = AnimatedVisualizationView(audioData: audioData, mood: mood, sensitivity: 1.0)
            _ = view.body
        }
    }
    
    func testParticleScenePerformance() {
        measure {
            let size = CGSize(width: 300, height: 300)
            let scene = ParticleScene(size: size, mood: .energetic)
            scene.update(1.0)
        }
    }
}
