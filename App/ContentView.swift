import SwiftUI
import GlassUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Background tint
            LinearGradient(colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Encorely")
                    .font(.largeTitle.weight(.semibold))

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome")
                            .font(.title3.weight(.semibold))
                        Text("This is the Encorely app — a SwiftUI front‑end using GlassUI and AudioKitEncorely. Not a service.")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .padding(.horizontal)

                Text("Starter UI. Plug in features next: Now Playing, Recorder, Visualizers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
