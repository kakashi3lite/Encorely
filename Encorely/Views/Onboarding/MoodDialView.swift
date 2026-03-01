import SwiftUI

// MARK: - Mood Dial View

/// Hi-Fi rotary knob for setting the user's energy baseline (0–1).
/// The dial sits in the lower half of the screen for thumb reachability.
/// Background is transparent -- the container owns it.
struct MoodDialView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    /// Current rotation angle in degrees for the indicator dot.
    @State private var rotation: Double = 180

    /// Haptic generator -- fires every ~10° of rotation.
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    /// Angle (degrees) at which the last haptic fired.
    @State private var lastHapticDegrees: Double = 180

    /// Dial diameter constant.
    private let dialSize: CGFloat = 280

    var body: some View {
        VStack {
            Spacer()

            // Dynamic energy label (top half)
            VStack(spacing: 4) {
                Text(viewModel.energyLabel)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText())
                    .animation(.snappy, value: viewModel.energyLevel)

                Text("Set your baseline energy")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            Spacer()

            // The dial (lower half for thumb reachability)
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .orange, .purple],
                            center: .center
                        )
                    )
                    .blur(radius: 40)
                    .opacity(0.5)
                    .frame(width: dialSize - 30, height: dialSize - 30)

                // Frosted glass knob body
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: dialSize, height: dialSize)
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )

                // Center readout
                VStack(spacing: 4) {
                    Text("\(Int(viewModel.energyLevel * 100))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("ENERGY")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(3)
                }

                // Indicator dot on the rim
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .offset(x: dialSize / 2 - 18)
                    .rotationEffect(.degrees(rotation))
            }
            .gesture(dialDragGesture)
            .accessibilityLabel("Energy dial, \(viewModel.energyLabel)")
            .accessibilityValue("\(Int(viewModel.energyLevel * 100)) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: viewModel.energyLevel = min(1, viewModel.energyLevel + 0.1)
                case .decrement: viewModel.energyLevel = max(0, viewModel.energyLevel - 0.1)
                @unknown default: break
                }
            }

            Spacer()
                .frame(height: 80)
        }
        .padding()
    }

    // MARK: - Drag Gesture

    /// Converts a touch location into a rotation angle and maps it to 0–1 energy.
    private var dialDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: dialSize / 2, y: dialSize / 2)
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let radians = atan2(dy, dx)

                // Convert to degrees (0–360).
                var degrees = radians * 180 / .pi
                if degrees < 0 { degrees += 360 }

                withAnimation(.interactiveSpring) {
                    rotation = degrees
                    // Normalize: 0° (right) maps to top of the range.
                    viewModel.energyLevel = min(max(degrees / 360, 0), 1)
                }

                // Fire haptic every ~10°.
                if abs(degrees - lastHapticDegrees) > 10 {
                    haptic.impactOccurred()
                    lastHapticDegrees = degrees
                }
            }
    }
}
