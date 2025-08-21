import SwiftUI

// MARK: - Navigation Sidebar for iPads
public struct NavigationSidebar<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String {
    @Binding var selectedTab: T
    
    public init(selectedTab: Binding<T>) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Encorely")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Professional Audio Suite")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            
            Divider()
            
            // Navigation Items
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(T.allCases), id: \.self) { tab in
                        SidebarItem(
                            title: tab.rawValue,
                            icon: iconForTab(tab),
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            // Footer
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
    
    private func iconForTab(_ tab: T) -> String {
        // This is a simplified approach - in real implementation,
        // you'd want to make this more generic
        switch tab.rawValue {
        case "Home": return "house.fill"
        case "Recorder": return "mic.fill"
        case "Visualizer": return "waveform"
        case "Settings": return "gear"
        default: return "circle"
        }
    }
}

// MARK: - Sidebar Item
private struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .blue : .clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Action Button
public struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonBackground)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var buttonBackground: Color {
        switch colorScheme {
        case .dark:
            return .white.opacity(0.1)
        case .light:
            return .white.opacity(0.7)
        @unknown default:
            return .white.opacity(0.5)
        }
    }
}

// MARK: - Feature Row
public struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    public init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Row
public struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    public init(title: String, subtitle: String, icon: String) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Audio Level Meter
public struct AudioLevelMeter: View {
    let level: Float
    let barCount: Int
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(level: Float, barCount: Int = 20) {
        self.level = level
        self.barCount = barCount
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(colorForBar(at: index))
                    .frame(maxWidth: .infinity)
                    .opacity(shouldShowBar(at: index) ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
    
    private func shouldShowBar(at index: Int) -> Bool {
        let threshold = Float(index) / Float(barCount)
        return level > threshold
    }
    
    private func colorForBar(at index: Int) -> Color {
        let position = Float(index) / Float(barCount)
        
        switch position {
        case 0..<0.6:
            return .green
        case 0.6..<0.85:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Performance Monitor
@MainActor
public class PerformanceMonitor: ObservableObject {
    @Published public var fps: Double = 60.0
    @Published public var memoryUsage: Double = 0.0
    
    #if os(iOS)
    private var displayLink: CADisplayLink?
    #endif
    private var timer: Timer?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    public init() {
        startMonitoring()
    }
    
    public func startMonitoring() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
        } else {
            startTimerBasedMonitoring()
        }
        #else
        startTimerBasedMonitoring()
        #endif
    }
    
    public func stopMonitoring() {
        #if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        #endif
        timer?.invalidate()
        timer = nil
    }
    
    private func startTimerBasedMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMemoryUsage()
                self.fps = 60.0 // Assume 60 FPS when using timer
            }
        }
    }
    
    #if os(iOS)
    @objc private func update() {
        guard let displayLink = displayLink else { return }
        
        let currentTime = displayLink.timestamp
        frameCount += 1
        
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            return
        }
        
        let elapsed = currentTime - lastTimestamp
        
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = currentTime
            
            updateMemoryUsage()
        }
    }
    #endif
    
    private func updateMemoryUsage() {
        #if os(iOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { pointer in
                task_info(mach_task_self(), task_flavor_t(MACH_TASK_BASIC_INFO), pointer, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / 1024 / 1024 // MB
        }
        #else
        // Fallback for non-iOS platforms
        memoryUsage = 0.0
        #endif
    }
}

// MARK: - Error Handler
public class ErrorHandler: ObservableObject {
    @Published public var currentError: AppError?
    @Published public var showingError = false
    
    public init() {}
    
    public func handle(_ error: Error) {
        let appError = AppError.from(error)
        currentError = appError
        showingError = true
        
        // Log error for debugging
        print("❌ Error: \(appError.message)")
        if let underlyingError = appError.underlyingError {
            print("   Underlying: \(underlyingError)")
        }
    }
    
    public func clearError() {
        currentError = nil
        showingError = false
    }
}

// MARK: - App Error
public struct AppError: Error, Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let underlyingError: Error?
    
    public init(title: String, message: String, underlyingError: Error? = nil) {
        self.title = title
        self.message = message
        self.underlyingError = underlyingError
    }
    
    public static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        return AppError(
            title: "Unexpected Error",
            message: error.localizedDescription,
            underlyingError: error
        )
    }
}

// MARK: - Visualization Components

// MARK: - Waveform View
public struct WaveformView: View {
    let data: [Float]
    let color: Color
    let lineWidth: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(data: [Float], color: Color = .blue, lineWidth: CGFloat = 2) {
        self.data = data
        self.color = color
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            
            let path = createWaveformPath(in: size)
            
            // Draw waveform
            context.stroke(
                path,
                with: .color(color),
                lineWidth: lineWidth
            )
            
            // Add glow effect in dark mode
            if colorScheme == .dark {
                context.addFilter(.blur(radius: 2))
                context.stroke(
                    path,
                    with: .color(color.opacity(0.5)),
                    lineWidth: lineWidth * 2
                )
            }
        }
    }
    
    private func createWaveformPath(in size: CGSize) -> Path {
        var path = Path()
        
        let stepX = size.width / CGFloat(data.count - 1)
        let centerY = size.height / 2
        
        for (index, amplitude) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = centerY - (CGFloat(amplitude) * centerY)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

// MARK: - Spectrum View
public struct SpectrumView: View {
    let data: [Float]
    let color: Color
    let barSpacing: CGFloat
    
    public init(data: [Float], color: Color = .green, barSpacing: CGFloat = 1) {
        self.data = data
        self.color = color
        self.barSpacing = barSpacing
    }
    
    public var body: some View {
        Canvas { context, size in
            guard !data.isEmpty else { return }
            
            let barWidth = (size.width - CGFloat(data.count - 1) * barSpacing) / CGFloat(data.count)
            
            for (index, amplitude) in data.enumerated() {
                let x = CGFloat(index) * (barWidth + barSpacing)
                let barHeight = CGFloat(amplitude) * size.height
                let y = size.height - barHeight
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                
                // Color gradient based on frequency
                let hue = Double(index) / Double(data.count)
                let barColor = Color(hue: hue * 0.3, saturation: 0.8, brightness: 0.9)
                
                context.fill(
                    Path(rect),
                    with: .color(barColor)
                )
            }
        }
    }
}

// MARK: - Level Meter View
public struct LevelMeterView: View {
    let rmsLevel: Float
    let peakLevel: Float
    
    public init(rmsLevel: Float, peakLevel: Float) {
        self.rmsLevel = rmsLevel
        self.peakLevel = peakLevel
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("RMS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", rmsLevel))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            // RMS Level Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                    
                    Rectangle()
                        .fill(levelColor(for: rmsLevel))
                        .frame(width: geometry.size.width * CGFloat(rmsLevel))
                        .animation(.easeInOut(duration: 0.1), value: rmsLevel)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            HStack {
                Text("PEAK")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", peakLevel))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            // Peak Level Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                    
                    Rectangle()
                        .fill(levelColor(for: peakLevel))
                        .frame(width: geometry.size.width * CGFloat(peakLevel))
                        .animation(.easeInOut(duration: 0.05), value: peakLevel)
                    
                    // Peak indicator
                    if peakLevel > 0.85 {
                        Rectangle()
                            .fill(.red)
                            .frame(width: 2)
                            .position(x: geometry.size.width * CGFloat(peakLevel), y: 4)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
    
    private func levelColor(for level: Float) -> Color {
        switch level {
        case 0..<0.6:
            return .green
        case 0.6..<0.85:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Device Info
public struct DeviceInfo {
    public static var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
    
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    public static var screenSize: CGSize {
        #if os(iOS)
        return UIScreen.main.bounds.size
        #else
        return CGSize(width: 1024, height: 768) // Default fallback
        #endif
    }
    
    public static var scale: CGFloat {
        #if os(iOS)
        return UIScreen.main.scale
        #else
        return 1.0 // Default fallback
        #endif
    }
}