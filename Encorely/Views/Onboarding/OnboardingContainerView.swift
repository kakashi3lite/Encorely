import SwiftUI
import SwiftData

// MARK: - Onboarding Container View

/// Root view for the 3-step Sonic Identity onboarding flow.
///
/// Architecture: 3-layer ZStack.
///   Layer 1 (Background): Full-screen animated gradient, changes per step.
///   Layer 2 (Content):    Paged TabView with interactive views.
///   Layer 3 (HUD):        Page indicator + navigation button.
struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // LAYER 1: Dynamic background (fills entire screen)
            Group {
                if viewModel.currentStep == .synesthesia {
                    SynesthesiaBackground(color: viewModel.auraColor)
                } else {
                    Color.black
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: viewModel.currentStep)
            .animation(.easeInOut(duration: 0.5), value: viewModel.selectedColorHex)

            // LAYER 2: Paged content
            TabView(selection: $viewModel.currentStep) {
                GenreBubbleView()
                    .tag(OnboardingStep.genres)
                    .environment(viewModel)

                MoodDialView()
                    .tag(OnboardingStep.energy)
                    .environment(viewModel)

                SynesthesiaView()
                    .tag(OnboardingStep.synesthesia)
                    .environment(viewModel)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            // LAYER 3: HUD overlay (indicator + nav)
            VStack {
                Spacer()
                bottomHUD
            }
        }
        .environment(viewModel)
    }

    // MARK: - Bottom HUD

    private var bottomHUD: some View {
        HStack {
            // Page indicator dots (left-aligned)
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(viewModel.currentStep == step ? Color.white : Color.white.opacity(0.3))
                        .frame(
                            width: viewModel.currentStep == step ? 24 : 8,
                            height: 8
                        )
                        .animation(.spring, value: viewModel.currentStep)
                }
            }

            Spacer()

            // Action button (right-aligned)
            Button(action: handleNext) {
                Text(viewModel.isLastStep ? "Finish" : "Next")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 100, height: 50)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.2), radius: 10)
            }
            .disabled(!viewModel.canAdvance)
            .opacity(viewModel.canAdvance ? 1 : 0.4)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func handleNext() {
        if viewModel.isLastStep {
            viewModel.finalizeProfile(context: modelContext)
            dismiss()
        } else {
            withAnimation {
                viewModel.nextStep()
            }
        }
    }
}

// MARK: - Synesthesia Background

/// Full-screen animated aura that shifts to the user's chosen color.
/// Uses MeshGradient on iOS 18+, RadialGradient fallback on iOS 17.
struct SynesthesiaBackground: View {
    let color: Color

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0, 0),    SIMD2(0.5, 0),    SIMD2(1, 0),
                    SIMD2(0, 0.5),  SIMD2(0.5, 0.5),  SIMD2(1, 0.5),
                    SIMD2(0, 1),    SIMD2(0.5, 1),     SIMD2(1, 1)
                ],
                colors: [
                    .black,              color.opacity(0.3),  .black,
                    color.opacity(0.6),  color,               color.opacity(0.6),
                    .black,              color.opacity(0.3),  .black
                ],
                smoothsColors: true
            )
        } else {
            ZStack {
                Color.black
                RadialGradient(
                    colors: [color.opacity(0.6), .black],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .blur(radius: 50)
            }
        }
    }
}
