import SwiftUI

// MARK: - Genre Bubble View

/// Full-screen STOMP genre picker.
/// Bubbles scatter across the available space using a spiral distribution.
/// Background is transparent -- the container owns the background layer.
struct GenreBubbleView: View {
    @Environment(OnboardingViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading) {
            // Header text at the top with safe-area padding
            Text("Sonic Identity")
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .padding(.horizontal, 30)
                .padding(.top, 60)

            Text("Tap what resonates.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .padding(.horizontal, 30)

            // GeometryReader gives us the full available size for spiral placement.
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    ForEach(Array(viewModel.availableGenres.enumerated()), id: \.element) { index, genre in
                        BubbleNode(
                            genre: genre,
                            isSelected: viewModel.selectedGenres.contains(genre),
                            index: index,
                            total: viewModel.availableGenres.count,
                            center: center,
                            fieldSize: geometry.size
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                viewModel.toggleGenre(genre)
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // Selection counter pinned above the HUD
            selectionCounter
                .padding(.horizontal, 30)
                .padding(.bottom, 70)
        }
    }

    // MARK: - Counter

    private var selectionCounter: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.cyan)
            Text("\(viewModel.selectedGenres.count) selected")
                .foregroundStyle(.white.opacity(0.7))
            if !viewModel.hasEnoughGenres {
                Text("(min \(viewModel.minimumGenreCount))")
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .font(.footnote.weight(.medium))
    }
}

// MARK: - Bubble Node

/// A single genre bubble positioned on a spiral path.
/// Grows and glows when selected; gently floats with a per-bubble delay.
struct BubbleNode: View {
    let genre: STOMPGenre
    let isSelected: Bool
    let index: Int
    let total: Int
    let center: CGPoint
    let fieldSize: CGSize

    /// Spiral distribution: 3 full turns of Archimedes spiral.
    /// Radius grows with sqrt(index) for even area coverage.
    private var position: CGPoint {
        let ratio = Double(index) / Double(max(total - 1, 1))
        let angle = ratio * 2 * .pi * 3
        let maxRadius = min(fieldSize.width, fieldSize.height) / 2.5
        let radius = 50.0 + (ratio * maxRadius)
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    /// Bubble diameter: selected bubbles are larger.
    private var diameter: CGFloat { isSelected ? 110 : 90 }

    var body: some View {
        ZStack {
            // Frosted glass circle with neon stroke
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? genre.bubbleColor : .white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: isSelected ? .cyan.opacity(0.5) : .clear, radius: 15)

            // Genre label
            VStack(spacing: 2) {
                Image(systemName: genre.icon)
                    .font(.callout)
                Text(genre.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
        .position(position)
        // Gentle float: selected bubbles bob up slightly
        .offset(y: isSelected ? -5 : 0)
        .animation(
            .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1),
            value: isSelected
        )
        .accessibilityLabel("\(genre.rawValue), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
