import SwiftUI

/// A thin progress bar that sits at the top of the mini player, showing playback progress.
struct NowPlayingBar: View {
    @Environment(AudioPlaybackService.self) private var playbackService
    @Environment(MoodEngine.self) private var moodEngine

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.quaternary)

                Rectangle()
                    .fill(moodEngine.currentMood.color)
                    .frame(width: geo.size.width * playbackService.progress)
                    .animation(.linear(duration: 0.3), value: playbackService.progress)
            }
        }
        .frame(height: 3)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
