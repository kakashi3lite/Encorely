import SwiftUI
import Combine

struct ModeToggle: View {
    @Binding var selectedMode: Int
    let aiService: AIIntegrationService
    
    private let modes = ["Player", "Podcast", "News"]
    private let icons = ["play.circle.fill", "mic.circle.fill", "newspaper.fill"]
    
    // Animation properties
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var previousMode = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background capsule
                Capsule()
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Foreground selector pill
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                aiService.personalityEngine.currentPersonality.themeColor,
                                aiService.moodEngine.currentMood.color
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: segmentWidth(geometry))
                    .offset(x: offsetForMode(geometry))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMode)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation.width
                                
                                // Calculate potential new mode based on drag
                                let segWidth = segmentWidth(geometry)
                                let currentOffset = CGFloat(selectedMode) * segWidth
                                let potentialOffset = currentOffset + dragOffset
                                let potentialMode = Int((potentialOffset + segWidth / 2) / segWidth)
                                
                                if potentialMode >= 0 && potentialMode < modes.count && potentialMode != selectedMode {
                                    hapticFeedback(style: .light)
                                    selectedMode = potentialMode
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                dragOffset = 0
                                if previousMode != selectedMode {
                                    previousMode = selectedMode
                                    aiService.trackInteraction(type: "switch_mode_to_\(modes[selectedMode].lowercased())")
                                }
                            }
                    )
                
                // Mode buttons
                HStack(spacing: 0) {
                    ForEach(0..<modes.count, id: \.self) { index in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedMode != index {
                                    hapticFeedback(style: .medium)
                                    selectedMode = index
                                    aiService.trackInteraction(type: "switch_mode_to_\(modes[index].lowercased())")
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: icons[index])
                                    .font(.system(size: 14, weight: .semibold))
                                Text(modes[index])
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(selectedMode == index ? .white : .primary)
                            .frame(width: segmentWidth(geometry), height: geometry.size.height)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .frame(height: 38)
        .padding(.horizontal, 16)
        .onAppear {
            previousMode = selectedMode
        }
    }
    
    private func segmentWidth(_ geometry: GeometryProxy) -> CGFloat {
        return geometry.size.width / CGFloat(modes.count)
    }
    
    private func offsetForMode(_ geometry: GeometryProxy) -> CGFloat {
        let baseOffset = CGFloat(selectedMode) * segmentWidth(geometry)
        return isDragging ? baseOffset + dragOffset : baseOffset
    }
    
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct AnimatedModeSelector: View {
    @Binding var selectedMode: Int
    let aiService: AIIntegrationService
    
    var body: some View {
        VStack(spacing: 8) {
            ModeToggle(selectedMode: $selectedMode, aiService: aiService)
                .frame(maxWidth: 340)
        }
        .padding(.vertical, 8)
    }
}
