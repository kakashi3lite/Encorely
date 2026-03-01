import Foundation
import SwiftUI
import SwiftData

// MARK: - Onboarding Step

/// Steps in the onboarding flow.
/// Container uses a paged TabView keyed on these values.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case genres = 0
    case energy = 1
    case synesthesia = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .genres:       "Sonic Identity"
        case .energy:       "Set Your Vibe"
        case .synesthesia:  "Pick Your Aura"
        }
    }

    var subtitle: String {
        switch self {
        case .genres:       "Tap what resonates."
        case .energy:       "Spin the dial to find your energy"
        case .synesthesia:  "What color does your music sound like?"
        }
    }
}

// MARK: - Onboarding ViewModel

/// Observable state manager for the 3-step Sonic Identity onboarding.
/// Holds all transient selections until the user finalizes and saves to SwiftData.
@Observable
final class OnboardingViewModel {

    // MARK: - Step Navigation

    /// Current visible step in the paged onboarding flow.
    var currentStep: OnboardingStep = .genres

    // MARK: - Bubble Verse State (STOMP Genre Selection)

    /// All 14 STOMP genres available for selection.
    let availableGenres: [STOMPGenre] = STOMPGenre.allCases

    /// Set of genres the user has tapped/selected.
    var selectedGenres: Set<STOMPGenre> = []

    /// Minimum genres required before the user can proceed.
    let minimumGenreCount = 3

    /// Whether enough genres have been picked to move forward.
    var hasEnoughGenres: Bool {
        selectedGenres.count >= minimumGenreCount
    }

    // MARK: - Mood Tuner State

    /// Energy baseline from the rotary dial (0.0 = Chill, 1.0 = Hyper).
    var energyLevel: Double = 0.5

    /// Human-readable label for the current energy level.
    var energyLabel: String {
        switch energyLevel {
        case 0..<0.2:   "Deep Chill"
        case 0.2..<0.4: "Mellow"
        case 0.4..<0.6: "Balanced"
        case 0.6..<0.8: "Energized"
        default:         "Hyper"
        }
    }

    // MARK: - Synesthesia State

    /// Predefined color palette for the picker.
    let colorPalette: [(name: String, hex: String)] = [
        ("Electric Cyan",   "#00FFFF"),
        ("Neon Violet",     "#BF40FF"),
        ("Solar Gold",      "#FFD700"),
        ("Ember Red",       "#FF4500"),
        ("Ocean Blue",      "#0077BE"),
        ("Forest Green",    "#228B22"),
        ("Hot Pink",        "#FF69B4"),
        ("Midnight Indigo", "#3F00FF"),
        ("Sunset Orange",   "#FF6347"),
        ("Arctic White",    "#F0F8FF"),
    ]

    /// Currently selected color hex, or nil if nothing picked yet.
    var selectedColorHex: String?

    /// Resolved SwiftUI Color for the current selection, or nil.
    var selectedColor: Color? {
        guard let hex = selectedColorHex else { return nil }
        return Color(hex: hex)
    }

    /// Non-optional color for backgrounds. Falls back to near-black.
    var auraColor: Color {
        selectedColor ?? Color(hex: "#111111")
    }

    /// Whether the user has picked a color and can finalize.
    var canFinalize: Bool {
        selectedColorHex != nil
    }

    // MARK: - Profile Completion Flag

    /// Set to true after a successful save. Drives navigation away from onboarding.
    var isComplete = false

    // MARK: - Genre Toggle

    /// Toggle a genre's selected state for the Bubble Verse.
    func toggleGenre(_ genre: STOMPGenre) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }

    // MARK: - STOMP Scoring

    /// Calculates the normalized score (0.0–1.0) for a given dimension.
    /// Score = (selected count in dimension) / (total genres in dimension).
    func score(for dimension: STOMPDimension) -> Double {
        let genresInDimension = dimension.genres
        let selectedCount = genresInDimension.filter { selectedGenres.contains($0) }.count
        guard !genresInDimension.isEmpty else { return 0 }
        return Double(selectedCount) / Double(genresInDimension.count)
    }

    /// All four dimension scores as a dictionary.
    var allScores: [STOMPDimension: Double] {
        Dictionary(uniqueKeysWithValues: STOMPDimension.allCases.map { ($0, score(for: $0)) })
    }

    // MARK: - Finalize & Persist

    /// Builds a SonicProfile from current state and inserts it into SwiftData.
    @MainActor
    func finalizeProfile(context: ModelContext) {
        let profile = SonicProfile(
            reflectiveComplex: score(for: .reflectiveComplex),
            intenseRebellious: score(for: .intenseRebellious),
            upbeatConventional: score(for: .upbeatConventional),
            energeticRhythmic: score(for: .energeticRhythmic),
            energyBaseline: energyLevel,
            synesthesiaColorHex: selectedColorHex ?? "#00FFFF"
        )
        context.insert(profile)
        try? context.save()
        isComplete = true
    }

    // MARK: - Navigation Helpers

    /// Advance to the next step.
    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    /// Go back to the previous step.
    func previousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    /// Whether a "Next" action should be enabled for the current step.
    var canAdvance: Bool {
        switch currentStep {
        case .genres:      hasEnoughGenres
        case .energy:      true
        case .synesthesia: canFinalize
        }
    }

    /// Whether the current step is the last one.
    var isLastStep: Bool {
        currentStep == .synesthesia
    }
}
