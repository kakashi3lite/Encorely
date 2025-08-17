import SwiftUI

struct QueueView: View {
    @ObservedObject var playerManager: PlayerManager
    @State private var draggingItem: Song?
    @State private var showConfirmation = false
    @State private var itemToRemove: Song?

    var body: some View {
        VStack(spacing: 0) {
            if playerManager.queue.isEmpty {
                EmptyQueueView()
            } else {
                List {
                    ForEach(playerManager.queue) { song in
                        ReorderableQueueItem(
                            title: song.title,
                            subtitle: song.artist,
                            artwork: song.artwork,
                            isPlaying: song == playerManager.currentSong,
                            onTap: { playerManager.play(song) },
                            onDelete: {
                                itemToRemove = song
                                showConfirmation = true
                            }
                        )
                        .onDrag {
                            draggingItem = song
                            return NSItemProvider()
                        }
                        .onDrop(of: [.text],
                                delegate: QueueDropDelegate(
                                    item: song,
                                    draggingItem: $draggingItem,
                                    playerManager: playerManager
                                ))
                    }
                }
                .listStyle(.plain)
            }
        }
        .overlay(
            Group {
                if showConfirmation {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ConfirmationDialog(
                                title: "Remove from Queue",
                                message: "Are you sure you want to remove this song from the queue?",
                                primaryButtonLabel: "Remove",
                                secondaryButtonLabel: "Cancel",
                                destructive: true,
                                primaryAction: {
                                    if let song = itemToRemove {
                                        withAnimation {
                                            playerManager.remove(song)
                                        }
                                    }
                                    showConfirmation = false
                                },
                                secondaryAction: {
                                    showConfirmation = false
                                }
                            ))
                }
            })
    }
}

struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Queue is Empty")
                .font(.headline)

            Text("Add songs to your queue to start playing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }
}

struct QueueDropDelegate: DropDelegate {
    let item: Song
    @Binding var draggingItem: Song?
    let playerManager: PlayerManager

    func performDrop(info _: DropInfo) -> Bool {
        guard let draggingItem else { return false }
        playerManager.move(draggingItem, after: item)
        return true
    }

    func dropEntered(info _: DropInfo) {
        guard let draggingItem,
              draggingItem != item else { return }

        playerManager.move(draggingItem, after: item)
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
