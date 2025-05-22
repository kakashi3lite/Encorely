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
        #if os(macOS)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Performance Settings...") {
                    showPerformanceSettings()
                }
                .keyboardShortcut("P", modifiers: [.command, .option])
            }
        }
        
        // Add a separate window for performance settings
        Window("Performance Settings", id: "performance_settings") {
            PerformanceSettingsView()
        }
        #endif
    }
    
    #if os(macOS)
    private func showPerformanceSettings() {
        NSApp.sendAction(Selector(("showPerformanceSettings:")), to: nil, from: nil)
    }
    #endif
    
    private func setupPerformanceMonitoring() {
        // Report initial memory usage
        PerformanceMonitor.shared.reportMemoryUsage()
        
        // Setup periodic memory usage reporting
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            PerformanceMonitor.shared.reportMemoryUsage()
        }
    }
}