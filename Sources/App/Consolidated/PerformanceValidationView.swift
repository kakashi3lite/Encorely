import SwiftUI

struct PerformanceValidationView: View {
    @StateObject private var viewModel = PerformanceValidationViewModel()
    
    var body: some View {
        List {
            Section(header: Text("Audio Processing Performance")) {
                HStack {
                    Text("Overall Status")
                    Spacer()
                    if let results = viewModel.results {
                        StatusBadge(passed: results.overallPassed)
                    } else {
                        Text("Not Run").foregroundColor(.secondary)
                    }
                }
                
                if let results = viewModel.results {
                    ValidationResultRow(title: "Latency", 
                                      passed: results.latencyResult.passed,
                                      detail: "\(String(format: "%.1f", results.latencyResult.averageLatencyMs))ms",
                                      target: "<100ms")
                    
                    ValidationResultRow(title: "Memory Usage", 
                                      passed: results.memoryResult.passed,
                                      detail: "\(String(format: "%.1f", results.memoryResult.peakMemoryMB))MB",
                                      target: "<50MB")
                    
                    ValidationResultRow(title: "Mood Detection", 
                                      passed: results.accuracyResult.passed,
                                      detail: "\(String(format: "%.1f", results.accuracyResult.accuracy * 100))%",
                                      target: ">80%")
                }
            }
            
            if let results = viewModel.results, 
               let detailedResults = viewModel.detailedMoodResults, 
               !detailedResults.isEmpty {
                Section(header: Text("Mood Detection Details")) {
                    ForEach(detailedResults, id: \.expectedMood.rawValue) { result in
                        HStack {
                            Text("\(result.expectedMood.rawValue)")
                                .font(.body)
                            Spacer()
                            Text("\(result.predictedMood.rawValue)")
                                .foregroundColor(result.isCorrect ? .primary : .red)
                            Text("\(Int(result.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isCorrect ? .green : .red)
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    viewModel.runValidation()
                }) {
                    if viewModel.isValidating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Testing...")
                        }
                    } else {
                        Text("Run Performance Validation")
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isValidating)
            }
        }
        .navigationTitle("Performance Validation")
        .onAppear {
            viewModel.setupNotifications()
        }
        .onDisappear {
            viewModel.removeNotifications()
        }
    }
}

// Status badge for pass/fail indication
struct StatusBadge: View {
    let passed: Bool
    
    var body: some View {
        Text(passed ? "PASSED" : "FAILED")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(passed ? Color.green : Color.red)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

// Row for individual validation results
struct ValidationResultRow: View {
    let title: String
    let passed: Bool
    let detail: String
    let target: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(target)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(detail)
                    .font(.body)
                    .fontWeight(.medium)
            }
            StatusBadge(passed: passed)
        }
    }
}

class PerformanceValidationViewModel: ObservableObject {
    @Published var results: ValidationResult?
    @Published var isValidating = false
    @Published var detailedMoodResults: [MoodTestResult]?
    
    private let performanceMonitor = PerformanceMonitor.shared
    
    func runValidation() {
        isValidating = true
        
        Task {
            let validationResults = await performanceMonitor.validateAudioProcessingSystem()
            
            DispatchQueue.main.async {
                self.results = validationResults
                self.detailedMoodResults = validationResults.accuracyResult.detailedResults
                self.isValidating = false
            }
        }
    }
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleValidationCompleted),
            name: .audioProcessingValidationCompleted,
            object: nil
        )
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleValidationCompleted(_ notification: Notification) {
        if let results = notification.userInfo?["results"] as? ValidationResult {
            DispatchQueue.main.async {
                self.results = results
                self.detailedMoodResults = results.accuracyResult.detailedResults
                self.isValidating = false
            }
        }
    }
}

struct PerformanceValidationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PerformanceValidationView()
        }
    }
}
