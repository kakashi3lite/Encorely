import Foundation
import Observation
import SwiftData

/// Manages library-level operations like deleting and filtering mixtapes.
@Observable
final class LibraryViewModel {
    var searchText: String = ""
    var showingGrid: Bool = true

    /// Deletes a mixtape from the model context.
    func delete(mixtape: Mixtape, from context: ModelContext) {
        context.delete(mixtape)
        try? context.save()
    }

    /// Sorts mixtapes by a given criteria.
    func sorted(_ mixtapes: [Mixtape], by sort: SortOption) -> [Mixtape] {
        switch sort {
        case .newest:      mixtapes.sorted { $0.createdDate > $1.createdDate }
        case .oldest:      mixtapes.sorted { $0.createdDate < $1.createdDate }
        case .mostPlayed:  mixtapes.sorted { $0.playCount > $1.playCount }
        case .alphabetical: mixtapes.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case mostPlayed = "Most Played"
        case alphabetical = "A–Z"
    }
}
