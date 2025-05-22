import SwiftUI
import SpriteKit
import Combine

struct AnimatedVisualizationView: View {
    let audioData: [Float]
    let mood: Mood
    let sensitivity: Double
    
    @State private var isAnimating = false
    @State private var particleScene: ParticleScene?
    
    init(audioData: [Float], mood: Mood, sensitivity: Double = 1.0) {
        self.audioData = audioData
        self.mood = mood
        self.sensitivity = sensitivity
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Particle effects layer
                SpriteView(scene: getParticleScene(size: geometry.size))
                    .ignoresSafeArea()
                
                // Waveform layer
                WaveformView(audioData: audioData, mood: mood)
                    .opacity(0.8)
                
                // Mood indicators
                MoodIndicatorOverlay(mood: mood)
                    .opacity(isAnimating ? 0.7 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
    
    private func getParticleScene(size: CGSize) -> SKScene {
        if particleScene == nil {
            particleScene = ParticleScene(size: size, mood: mood)
        }
        return particleScene!
    }
}

// MARK: - Waveform View
private struct WaveformView: View {
    let audioData: [Float]
    let mood: Mood
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                let spacing = width / CGFloat(audioData.count - 1)
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for i in 0..<audioData.count {
                    let x = spacing * CGFloat(i)
                    let normalizedAmplitude = CGFloat(audioData[i])
                    let y = midHeight + normalizedAmplitude * midHeight
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        let control1 = CGPoint(x: x - spacing/2, y: y)
                        let control2 = CGPoint(x: x - spacing/2, y: y)
                        path.addCurve(to: CGPoint(x: x, y: y),
                                    control1: control1,
                                    control2: control2)
                    }
                }
            }
            .trim(from: 0, to: 1)
            .stroke(
                getMoodGradient(),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .animation(.linear(duration: 0.1), value: audioData)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 2 * .pi
                }
            }
        }
    }
    
    private func getMoodGradient() -> LinearGradient {
        switch mood {
        case .calm:
            return LinearGradient(
                colors: [.blue.opacity(0.6), .cyan.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .energetic:
            return LinearGradient(
                colors: [.orange.opacity(0.8), .red.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .happy:
            return LinearGradient(
                colors: [.yellow.opacity(0.6), .green.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .melancholic:
            return LinearGradient(
                colors: [.purple.opacity(0.6), .indigo.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [.gray.opacity(0.6), .white.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Particle Scene
class ParticleScene: SKScene {
    private var mood: Mood
    private var emitter: SKEmitterNode?
    
    init(size: CGSize, mood: Mood) {
        self.mood = mood
        super.init(size: size)
        setupScene()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 2.0
        emitter.numParticlesToEmit = -1
        emitter.particleLifetime = 4.0
        emitter.particleLifetimeRange = 1.0
        emitter.particleAlpha = 0.5
        emitter.particleAlphaRange = 0.25
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.05
        emitter.position = CGPoint(x: size.width/2, y: size.height/2)
        
        switch mood {
        case .calm:
            emitter.particleColor = .blue
        case .energetic:
            emitter.particleColor = .orange
        case .happy:
            emitter.particleColor = .yellow
        case .melancholic:
            emitter.particleColor = .purple
        default:
            emitter.particleColor = .gray
        }
        
        self.emitter = emitter
        addChild(emitter)
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        emitter?.particleBirthRate = mood == .energetic ? 4.0 : 2.0
    }
}

// MARK: - Mood Indicator Overlay
private struct MoodIndicatorOverlay: View {
    let mood: Mood
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { _ in
                Circle()
                    .fill(getMoodColor())
                    .frame(width: 8, height: 8)
                    .opacity(0.6)
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(getMoodColor(), lineWidth: 1)
        )
    }
    
    private func getMoodColor() -> Color {
        switch mood {
        case .calm: return .blue
        case .energetic: return .orange
        case .happy: return .yellow
        case .melancholic: return .purple
        default: return .gray
        }
    }
}

// MARK: - Preview
struct AnimatedVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedVisualizationView(
            audioData: Array(repeating: Float.random(in: -1...1), count: 40),
            mood: .energetic
        )
        .frame(height: 300)
        .preferredColorScheme(.dark)
    }
}
