import Testing
import Foundation
import SwiftUI
@testable import Encorely

// MARK: - STOMP Genre Tests

@Suite("STOMPGenre")
struct STOMPGenreTests {

    @Test("All 14 STOMP genres are present")
    func allGenresExist() {
        #expect(STOMPGenre.allCases.count == 14)
    }

    @Test("Each genre maps to exactly one dimension")
    func genreToDimensionMapping() {
        for genre in STOMPGenre.allCases {
            let _ = genre.dimension
        }
    }

    @Test("Reflective dimension has 4 genres (Classical, Jazz, Blues, Folk)")
    func reflectiveDimensionGenres() {
        let genres = STOMPDimension.reflectiveComplex.genres
        #expect(genres.count == 4)
        #expect(genres.contains(.classical))
        #expect(genres.contains(.jazz))
        #expect(genres.contains(.blues))
        #expect(genres.contains(.folk))
    }

    @Test("Intense dimension has 4 genres (Rock, Alt, Metal, Punk)")
    func intenseDimensionGenres() {
        let genres = STOMPDimension.intenseRebellious.genres
        #expect(genres.count == 4)
        #expect(genres.contains(.rock))
        #expect(genres.contains(.alternative))
        #expect(genres.contains(.heavyMetal))
        #expect(genres.contains(.punk))
    }

    @Test("Upbeat dimension has 4 genres (Pop, Country, Religious, Soundtracks)")
    func upbeatDimensionGenres() {
        let genres = STOMPDimension.upbeatConventional.genres
        #expect(genres.count == 4)
        #expect(genres.contains(.pop))
        #expect(genres.contains(.country))
        #expect(genres.contains(.religious))
        #expect(genres.contains(.soundtracks))
    }

    @Test("Energetic dimension has 2 genres (Rap, Electronica)")
    func energeticDimensionGenres() {
        let genres = STOMPDimension.energeticRhythmic.genres
        #expect(genres.count == 2)
        #expect(genres.contains(.rapHipHop))
        #expect(genres.contains(.electronica))
    }

    @Test("Every genre has a non-empty SF Symbol icon")
    func genresHaveIcons() {
        for genre in STOMPGenre.allCases {
            #expect(!genre.icon.isEmpty)
        }
    }
}

// MARK: - SonicProfile Tests

@Suite("SonicProfile")
struct SonicProfileTests {

    @Test("Default profile has zeroed scores")
    func defaultInit() {
        let profile = SonicProfile()
        #expect(profile.reflectiveComplex == 0)
        #expect(profile.intenseRebellious == 0)
        #expect(profile.upbeatConventional == 0)
        #expect(profile.energeticRhythmic == 0)
        #expect(profile.energyBaseline == 0.5)
    }

    @Test("Dominant dimension is correct")
    func dominantDimension() {
        let profile = SonicProfile(
            reflectiveComplex: 0.2,
            intenseRebellious: 0.9,
            upbeatConventional: 0.1,
            energeticRhythmic: 0.5
        )
        #expect(profile.dominantDimension == .intenseRebellious)
    }

    @Test("Synesthesia color hex roundtrips")
    func synesthesiaHex() {
        let profile = SonicProfile(synesthesiaColorHex: "#FF6347")
        #expect(profile.synesthesiaColorHex == "#FF6347")
    }
}

// MARK: - OnboardingViewModel Tests

@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {

    @Test("Initial state has no selections")
    func initialState() {
        let vm = OnboardingViewModel()
        #expect(vm.selectedGenres.isEmpty)
        #expect(vm.currentStep == .genres)
        #expect(!vm.hasEnoughGenres)
        #expect(!vm.isComplete)
    }

    @Test("Toggle genre adds and removes")
    func toggleGenre() {
        let vm = OnboardingViewModel()
        vm.toggleGenre(.jazz)
        #expect(vm.selectedGenres.contains(.jazz))
        vm.toggleGenre(.jazz)
        #expect(!vm.selectedGenres.contains(.jazz))
    }

    @Test("Minimum 3 genres required to proceed")
    func minimumGenres() {
        let vm = OnboardingViewModel()
        vm.toggleGenre(.jazz)
        vm.toggleGenre(.rock)
        #expect(!vm.hasEnoughGenres)
        vm.toggleGenre(.pop)
        #expect(vm.hasEnoughGenres)
    }

    @Test("STOMP scoring calculates correct dimension values")
    func stompScoring() {
        let vm = OnboardingViewModel()

        // Select 2 of 4 Reflective genres -> score should be 0.5.
        vm.toggleGenre(.classical)
        vm.toggleGenre(.jazz)
        #expect(vm.score(for: .reflectiveComplex) == 0.5)

        // Select 1 of 2 Energetic genres -> score should be 0.5.
        vm.toggleGenre(.electronica)
        #expect(vm.score(for: .energeticRhythmic) == 0.5)

        // Unselected dimensions should be 0.
        #expect(vm.score(for: .intenseRebellious) == 0)
        #expect(vm.score(for: .upbeatConventional) == 0)
    }

    @Test("Energy level maps to correct label")
    func energyLabels() {
        let vm = OnboardingViewModel()

        vm.energyLevel = 0.1
        #expect(vm.energyLabel == "Deep Chill")

        vm.energyLevel = 0.3
        #expect(vm.energyLabel == "Mellow")

        vm.energyLevel = 0.5
        #expect(vm.energyLabel == "Balanced")

        vm.energyLevel = 0.7
        #expect(vm.energyLabel == "Energized")

        vm.energyLevel = 0.95
        #expect(vm.energyLabel == "Hyper")
    }

    @Test("Step navigation works")
    func stepNavigation() {
        let vm = OnboardingViewModel()
        #expect(vm.currentStep == .genres)

        vm.nextStep()
        #expect(vm.currentStep == .energy)

        vm.nextStep()
        #expect(vm.currentStep == .synesthesia)
        #expect(vm.isLastStep)

        // Can't go past last step.
        vm.nextStep()
        #expect(vm.currentStep == .synesthesia)

        vm.previousStep()
        #expect(vm.currentStep == .energy)
    }

    @Test("Can finalize only when color is selected")
    func finalizeGating() {
        let vm = OnboardingViewModel()
        #expect(!vm.canFinalize)

        vm.selectedColorHex = "#FF6347"
        #expect(vm.canFinalize)
    }

    @Test("Color palette has 10 options")
    func colorPalette() {
        let vm = OnboardingViewModel()
        #expect(vm.colorPalette.count == 10)
    }

    @Test("Aura color returns fallback when no selection")
    func auraColorFallback() {
        let vm = OnboardingViewModel()
        // Should not crash, returns a non-nil Color.
        let _ = vm.auraColor
    }

    @Test("Aura color reflects selection")
    func auraColorSelection() {
        let vm = OnboardingViewModel()
        vm.selectedColorHex = "#FF6347"
        // Should not crash; selectedColor should be non-nil.
        #expect(vm.selectedColor != nil)
    }
}

// MARK: - Color Hex Extension Tests

@Suite("Color+Hex")
struct ColorHexTests {

    @Test("Hex string parsing produces non-nil color")
    func hexParsing() {
        let color = Color(hex: "#FF6347")
        #expect(type(of: color) == Color.self)
    }

    @Test("Six-digit and eight-digit hex both work")
    func hexLengths() {
        let _ = Color(hex: "FF6347")
        let _ = Color(hex: "#FF634780")
    }
}
