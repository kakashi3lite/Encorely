import SwiftUI

@main
struct AIMixtapesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .trackPerformance(identifier: "main_view_lifecycle")
                .onAppear {
                    setupPerformanceMonitoring()
                }
        }
    }
    
    private func setupPerformanceMonitoring() {
        // Report initial memory usage
        PerformanceMonitor.shared.reportMemoryUsage()
        
        // Setup periodic memory usage reporting
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            PerformanceMonitor.shared.reportMemoryUsage()
        }
    }
}