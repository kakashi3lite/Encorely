import XCTest
import AVFoundation
import Combine
@testable import AIMixtapes

/// Tests for the enhanced AudioAnalysisService
class AudioAnalysisServiceTests: XCTestCase {
    var audioAnalysisService: AudioAnalysisService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        audioAnalysisService = AudioAnalysisService()
    }
    
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = []
        audioAnalysisService = nil
        super.tearDown()
    }
    
    /// Tests the creation of spectral features
    func testSpectralFeatureCreation() {
        // Create a mock spectral features set
        var spectralFeatures = SpectralFeatures()
        spectralFeatures.centroid = 2000.0
        spectralFeatures.spread = 1500.0
        spectralFeatures.rolloff = 4000.0
        spectralFeatures.flux = 0.6
        spectralFeatures.bassEnergy = 0.8
        spectralFeatures.midEnergy = 0.5
        spectralFeatures.trebleEnergy = 0.3
        spectralFeatures.brightness = 0.7
        
        // Convert to audio features
        let audioFeatures = AudioFeatures.from(spectralFeatures: spectralFeatures)
        
        // Verify the conversion worked correctly
        XCTAssertEqual(audioFeatures.spectralFeatures?.centroid, 2000.0)
        XCTAssertEqual(audioFeatures.spectralFeatures?.spread, 1500.0)
        XCTAssertEqual(audioFeatures.spectralFeatures?.bassEnergy, 0.8)
        XCTAssertEqual(audioFeatures.energy, (0.8 + 0.5 + 0.3) / 3.0)
        XCTAssertGreaterThan(audioFeatures.valence ?? 0, 0.0)
        XCTAssertLessThan(audioFeatures.valence ?? 1.1, 1.0)
    }
    
    /// Tests the mood factory methods
    func testMoodFactoryMethods() {
        // Test different moods
        let energeticFeatures = AudioFeatures.forMood(.energetic)
        let relaxedFeatures = AudioFeatures.forMood(.relaxed)
        let happyFeatures = AudioFeatures.forMood(.happy)
        
        // Verify the features match the expected mood characteristics
        XCTAssertGreaterThan(energeticFeatures.energy ?? 0, 0.7)
        XCTAssertLessThan(relaxedFeatures.energy ?? 1.0, 0.5)
        XCTAssertGreaterThan(happyFeatures.valence ?? 0, 0.7)
    }
    
    /// Tests the performance metrics
    func testPerformanceMetrics() {
        var metrics = PerformanceMetrics()
        
        // Record some sample analysis data
        metrics.recordAnalysis(duration: 180.0, format: "44.1kHz, 2 channels", processingTime: 2.5, memoryUsed: 1024 * 1024)
        metrics.recordAnalysis(duration: 240.0, format: "44.1kHz, 2 channels", processingTime: 3.0, memoryUsed: 2 * 1024 * 1024)
        
        // Get the report and verify it contains expected information
        let report = metrics.generateReport()
        XCTAssertTrue(report.contains("Total files processed: 2"))
        XCTAssertTrue(report.contains("Total audio duration: 420"))
    }
    
    /// Tests distance and similarity calculations
    func testDistanceCalculation() {
        let featureSet1 = AudioFeatures(
            tempo: 120.0,
            energy: 0.8,
            valence: 0.7
        )
        
        let featureSet2 = AudioFeatures(
            tempo: 124.0,
            energy: 0.75,
            valence: 0.65
        )
        
        let featureSet3 = AudioFeatures(
            tempo: 80.0,
            energy: 0.3,
            valence: 0.2
        )
        
        // Similar features should have low distance
        let distance1to2 = featureSet1.distance(to: featureSet2)
        XCTAssertLessThan(distance1to2, 0.3)
        
        // Different features should have high distance
        let distance1to3 = featureSet1.distance(to: featureSet3)
        XCTAssertGreaterThan(distance1to3, 0.5)
        
        // Similarity is the inverse of distance
        let similarity1to2 = featureSet1.similarity(to: featureSet2)
        XCTAssertGreaterThan(similarity1to2, 0.7)
    }
}
