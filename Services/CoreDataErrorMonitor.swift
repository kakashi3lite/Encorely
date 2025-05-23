import SwiftUI
import Combine

/// Observable object that monitors Core Data errors
class CoreDataErrorMonitor: ObservableObject {
    @Published var currentError: Error?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for Core Data load errors
        NotificationCenter.default.publisher(for: Notification.Name("CoreDataLoadError"))
            .sink { [weak self] notification in
                if let error = notification.object as? Error {
                    DispatchQueue.main.async {
                        self?.currentError = error
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for Core Data save errors
        NotificationCenter.default.publisher(for: Notification.Name("CoreDataSaveError"))
            .sink { [weak self] notification in
                if let error = notification.object as? Error {
                    DispatchQueue.main.async {
                        self?.currentError = error
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func retryDataLoad() {
        // Implement retry logic here if needed
        // This could involve asking PersistenceController to try migration again
        currentError = nil
    }
}
