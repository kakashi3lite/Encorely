import SwiftData
import SwiftUI

/// Shows the user's mixtape collection in a grid or list layout.
struct LibraryView: View {
    @Query(sort: \Mixtape.createdDate, order: .reverse) private var mixtapes: [Mixtape]
    @Environment(\.modelContext) private var modelContext
    @State private var showingGrid = true
    @State private var searchText = ""

    private var filtered: [Mixtape] {
        guard !searchText.isEmpty else { return mixtapes }
        return mixtapes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No Mixtapes Yet",
                    message: "Tap Generate to create your first AI mixtape."
                )
            } else {
                ScrollView {
                    if showingGrid {
                        gridLayout
                    } else {
                        listLayout
                    }
                }
            }
        }
        .navigationTitle("Library")
        .searchable(text: $searchText, prompt: "Search mixtapes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showingGrid.toggle() }
                } label: {
                    Image(systemName: showingGrid ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel(showingGrid ? "Switch to list" : "Switch to grid")
            }
        }
    }

    // MARK: - Grid

    private var gridLayout: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
            spacing: 16
        ) {
            ForEach(filtered) { mixtape in
                NavigationLink(value: AppDestination.mixtapeDetail(mixtapeID: mixtape.mixtapeID)) {
                    MixtapeCard(mixtape: mixtape)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - List

    private var listLayout: some View {
        LazyVStack(spacing: 12) {
            ForEach(filtered) { mixtape in
                NavigationLink(value: AppDestination.mixtapeDetail(mixtapeID: mixtape.mixtapeID)) {
                    MixtapeRow(mixtape: mixtape)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Row

private struct MixtapeRow: View {
    let mixtape: Mixtape

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(mixtape.dominantMood.color.gradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: mixtape.dominantMood.systemIcon)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(mixtape.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(mixtape.songCount) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if mixtape.isAIGenerated {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mixtape.title), \(mixtape.songCount) songs, \(mixtape.dominantMood.rawValue) mood")
    }
}
