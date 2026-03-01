import SwiftUI

// MARK: - Synesthesia View

/// "What color does your favorite song sound like?"
/// A horizontal swatch picker that lets the user choose their aura color.
/// Background is transparent -- the container's SynesthesiaBackground handles it.
struct SynesthesiaView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            Spacer()
            colorSwatchRow
            selectedColorLabel
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("Pick Your Aura")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("What color does your music sound like?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 60)
    }

    // MARK: - Color Swatches

    private var colorSwatchRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(viewModel.colorPalette.enumerated()), id: \.element.hex) { _, swatch in
                    ColorSwatch(
                        name: swatch.name,
                        hex: swatch.hex,
                        isSelected: viewModel.selectedColorHex == swatch.hex
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            viewModel.selectedColorHex = swatch.hex
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
    }

    // MARK: - Selected Label

    /// Shows the name of the currently selected color.
    private var selectedColorLabel: some View {
        Group {
            if let hex = viewModel.selectedColorHex,
               let match = viewModel.colorPalette.first(where: { $0.hex == hex }) {
                Text(match.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color(hex: hex))
                    .transition(.opacity)
            } else {
                Text("Choose a color to continue")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.selectedColorHex)
    }
}

// MARK: - Color Swatch

/// A single tappable color circle with label and selection ring.
private struct ColorSwatch: View {
    let name: String
    let hex: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    // Selection ring
                    Circle()
                        .strokeBorder(.white, lineWidth: isSelected ? 3 : 0)
                        .frame(width: 72, height: 72)

                    // Color fill
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 62, height: 62)
                        .shadow(
                            color: Color(hex: hex).opacity(isSelected ? 0.7 : 0.2),
                            radius: isSelected ? 10 : 2
                        )
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(name)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.5))
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
