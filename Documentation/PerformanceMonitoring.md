# Performance Monitoring System

## Overview

The AI-Mixtapes app includes a comprehensive performance monitoring system that tracks CPU usage, memory consumption, disk usage, and audio processing load. This system helps ensure optimal app performance and provides early warnings when system resources are under pressure.

The performance monitoring system is designed to be lightweight yet powerful, with minimal impact on the app's performance while providing valuable insights into resource usage. It integrates with the app's configuration system to adapt monitoring behavior based on device capabilities and user settings.

## Key Components

### PerformanceMonitor

The `PerformanceMonitor` class is the central component of the performance monitoring system. It provides a shared singleton instance accessible throughout the app and handles all performance-related metrics.

```swift
let monitor = PerformanceMonitor.shared
```

The `PerformanceMonitor` class is responsible for:

- Tracking operation durations
- Monitoring memory, CPU, and disk usage
- Detecting and responding to performance warnings
- Validating audio processing performance
- Notifying the app of performance issues

### Performance Metrics

The system tracks several key metrics:

- **CPU Usage**: Percentage of CPU resources used by the app
- **Memory Usage**: Memory consumption in megabytes
- **Disk Usage**: Percentage of available disk space used
- **Audio Processing Load**: Percentage of available processing time used for audio tasks
- **Thermal State**: Current thermal state of the device

These metrics are encapsulated in the `PerformanceMetrics` struct:

```swift
struct PerformanceMetrics {
    /// Audio processing load as a percentage of available processing time
    let audioProcessingLoad: Double

    /// Memory usage in megabytes
    let memoryUsage: Double

    /// CPU usage as a percentage
    let cpuUsage: Double

    /// Disk usage as a percentage
    let diskUsage: Double

    /// Current thermal state of the device
    let thermalState: ProcessInfo.ThermalState
}
```

## Implementation Details

### Periodic Monitoring

The `PerformanceMonitor` sets up timers to periodically check system resources:

```swift
// Monitor CPU usage every 5 seconds
cpuUsageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
    self?.reportCPUUsage()
}

// Monitor disk usage every minute
diskUsageTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
    self?.reportDiskUsage()
}
```

### Memory Warning Handling

On iOS, the system automatically registers for memory warnings:

```swift
memoryWarningSubscriber = NotificationCenter.default
    .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
    .sink { [weak self] _ in
        self?.handleMemoryWarning()
    }
```

### Platform-Specific Adaptations

The system includes platform-specific code for iOS and macOS:

```swift
#if os(macOS)
    // macOS-specific memory pressure detection
    let hostPort = mach_host_self()
    var count = UInt32(HOST_VM_INFO64_COUNT)
    var vmStats = vm_statistics64_data_t()
    // Check virtual memory pressure
#else
    // iOS-specific handling
#endif
```

## Usage

### Getting Current Metrics

To retrieve the current performance metrics:

```swift
let metrics = PerformanceMonitor.shared.getCurrentMetrics()
print("Memory usage: \(metrics.memoryUsage) MB")
print("CPU usage: \(metrics.cpuUsage)%")
print("Audio processing load: \(metrics.audioProcessingLoad)%")
print("Disk usage: \(metrics.diskUsage)%")
print("Thermal state: \(metrics.thermalState)")
```

### Tracking Performance of Operations

You can track the performance of specific operations:

```swift
// Start tracking
PerformanceMonitor.shared.startTracking("audioProcessing")

// Perform operation
processAudio(buffer)

// End tracking (automatically logs duration and stores metrics)
PerformanceMonitor.shared.endTracking("audioProcessing")
```

The system stores periodic metrics for trend analysis, allowing you to identify performance degradation over time.

### SwiftUI Integration

Track the performance of SwiftUI views using the provided view modifier:

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            // View content
        }
        .trackPerformance(identifier: "ContentView")
    }
}
```

This modifier automatically calls `startTracking` on `onAppear` and `endTracking` on `onDisappear`.

### Responding to Performance Warnings

Register for notifications to respond to performance warnings:

```swift
NotificationCenter.default.addObserver(forName: .performanceHighMemoryPressure, object: nil, queue: .main) { _ in
    // Handle high memory pressure
    clearCaches()
}

NotificationCenter.default.addObserver(forName: .performanceHighCPUUsage, object: nil, queue: .main) { _ in
    // Handle high CPU usage
    reduceBackgroundTasks()
}
```

Available notifications:
- `.performanceMemoryWarning` - System memory warning received
- `.performanceHighMemoryPressure` - High memory pressure detected
- `.performanceHighCPUUsage` - CPU usage exceeds threshold
- `.performanceHighDiskUsage` - Disk usage exceeds threshold
- `.performanceHighAudioProcessingLoad` - Audio processing load exceeds configured maximum

## Audio Processing Validation

The system includes comprehensive functionality to validate audio processing performance. This validation ensures that the audio processing system meets the required performance constraints for real-time audio processing.

### Running Validation

```swift
Task {
    let results = await PerformanceMonitor.shared.validateAudioProcessingSystem()
    if results.overallPassed {
        print("Audio system validation passed")
    } else {
        print("Audio system validation failed")
        
        // Check specific validation results
        if !results.latencyResult.passed {
            print("Latency test failed: Average latency \(results.latencyResult.averageLatencyMs)ms exceeds threshold")
        }
        
        if !results.memoryResult.passed {
            print("Memory test failed: Peak memory usage \(results.memoryResult.peakMemoryMB)MB exceeds threshold")
        }
        
        if !results.accuracyResult.passed {
            print("Accuracy test failed: Accuracy \(results.accuracyResult.accuracy * 100)% below threshold")
        }
    }
}
```

### Validation Results

The validation process tests several aspects of audio processing performance:

1. **Latency**: Measures the time taken to process audio buffers and ensures it stays below the configured maximum latency.

2. **Memory Usage**: Monitors memory consumption during audio processing to ensure it doesn't exceed the configured maximum.

3. **Accuracy**: Verifies that the audio processing algorithms produce accurate results within acceptable error margins.

### Notification System

Validation results are broadcast via the `.audioProcessingValidationCompleted` notification, allowing different parts of the app to respond to validation results:

```swift
NotificationCenter.default.addObserver(forName: .audioProcessingValidationCompleted, object: nil, queue: .main) { notification in
    if let results = notification.userInfo?["results"] as? ValidationResult {
        // Handle validation results
        updateUIBasedOnValidationResults(results)
    }
}
```

## Configuration

Performance monitoring settings can be configured through the `AudioProcessingConfiguration` class:

```swift
let config = AudioProcessingConfiguration.shared
config.enablePerformanceMonitoring = true
config.maxProcessingLoad = 80.0 // 80%
config.maxMemoryUsage = 512 * 1024 * 1024 // 512 MB
```

## Best Practices

1. **Regular Monitoring**: Check performance metrics regularly in performance-critical sections of the app.

2. **Respond to Warnings**: Implement handlers for performance warning notifications to gracefully degrade functionality when resources are constrained.

3. **Track Key Operations**: Use the tracking API for performance-critical operations to identify bottlenecks.

4. **Validate After Changes**: Run the audio processing validation after making changes to audio processing code.

5. **Set Appropriate Thresholds**: Configure thresholds based on the specific requirements and constraints of your app and target devices.

## Performance Profiling

For deeper performance analysis, the system provides profiling capabilities:

### Time Profiling

```swift
// Profile a specific operation
PerformanceMonitor.shared.startProfiling(identifier: "audioProcessing")
// Perform operation
processAudioBuffer(buffer)
// End profiling and get results
let profile = PerformanceMonitor.shared.endProfiling(identifier: "audioProcessing")
print("Operation took \(profile.duration)ms with \(profile.memoryDelta)MB memory change")

// Profile with automatic duration measurement using closure
let profile = PerformanceMonitor.shared.profileOperation(identifier: "audioProcessing") {
    processAudioBuffer(buffer)
}
```

### Trend Analysis

The performance monitor stores historical data for trend analysis:

```swift
// Get performance history for the last hour
let history = PerformanceMonitor.shared.getPerformanceHistory(timeRange: .hour)

// Analyze trends
let cpuTrend = history.analyzeTrend(metric: .cpuUsage)
switch cpuTrend {
case .increasing:
    print("CPU usage is trending upward - potential memory leak")
case .decreasing:
    print("CPU usage is trending downward - optimization working")
case .stable:
    print("CPU usage is stable")
case .fluctuating:
    print("CPU usage is fluctuating - may indicate sporadic workload")
}
```

### Export Performance Data

```swift
// Export performance data for external analysis
let exportURL = try PerformanceMonitor.shared.exportPerformanceData(timeRange: .day)
print("Performance data exported to \(exportURL.path)")
```