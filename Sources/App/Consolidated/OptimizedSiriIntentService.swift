//
//  OptimizedSiriIntentService.swift
//  Mixtapes
//
//  Optimized SiriKit intent handling for better performance
//  Fixes ISSUE-010: SiriKit Intent Extension Optimization
//

import Combine
import CoreData
import Foundation
import Intents

/// Optimized SiriKit intent service with reduced latency and improved caching
class OptimizedSiriIntentService: NSObject, ObservableObject {
    // MARK: - Properties

    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private let context: NSManagedObjectContext

    // MARK: - Performance Optimization

    private let intentQueue = DispatchQueue(label: "siri.intent.queue", qos: .userInteractive)
    private let cacheQueue = DispatchQueue(label: "siri.cache.queue", attributes: .concurrent)
    private let workQueue = DispatchQueue(label: "siri.work.queue", qos: .userInitiated)
    private let performanceQueue = DispatchQueue(label: "siri.performance.queue", qos: .background)

    // MARK: - Memory Management

    private var memoryPressureTask: Task<Void, Never>?
    private var cachePurgeTimer: Timer?

    // MARK: - Cache Configuration

    private enum CacheConfig {
        static let maxCacheSize = 100
        static let defaultExpiryInterval: TimeInterval = 300 // 5 minutes
        static let extendedExpiryInterval: TimeInterval = 600 // 10 minutes
        static let cleanupInterval: TimeInterval = 60 // 1 minute
        static let memoryPressureThreshold = 50 * 1024 * 1024 // 50MB
    }

    // Memory-efficient cache structures
    private struct CachedItem<T> {
        let value: T
        let timestamp: Date
        var accessCount: Int
        var lastAccess: Date
        let cost: Int

        mutating func recordAccess() {
            accessCount += 1
            lastAccess = Date()
        }
    }

    private actor CacheManager<T> {
        private var cache: [String: CachedItem<T>] = [:]
        private var totalCost: Int = 0
        private let maxCost: Int

        init(maxCost: Int) {
            self.maxCost = maxCost
        }

        func get(_ key: String) -> T? {
            guard var item = cache[key],
                  item.timestamp.timeIntervalSinceNow > -CacheConfig.defaultExpiryInterval
            else {
                cache.removeValue(forKey: key)
                return nil
            }
            item.recordAccess()
            cache[key] = item
            return item.value
        }

        func set(_ key: String, value: T, cost: Int) {
            while totalCost + cost > maxCost {
                evictLRU()
            }

            let item = CachedItem(
                value: value,
                timestamp: Date(),
                accessCount: 1,
                lastAccess: Date(),
                cost: cost
            )

            cache[key] = item
            totalCost += cost
        }

        private func evictLRU() {
            guard let lru = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess }) else {
                return
            }
            cache.removeValue(forKey: lru.key)
            totalCost -= lru.value.cost
        }

        func clear() {
            cache.removeAll()
            totalCost = 0
        }
    }

    // MARK: - Memory Monitoring

    private actor MemoryMonitor {
        private var memoryUsageHistory: [Int] = []
        private let maxHistorySize = 10
        private let pressureThreshold = CacheConfig.memoryPressureThreshold

        func recordMemoryUsage(_ usage: Int) {
            if memoryUsageHistory.count >= maxHistorySize {
                memoryUsageHistory.removeFirst()
            }
            memoryUsageHistory.append(usage)
        }

        func shouldReduceMemory() -> Bool {
            guard let currentUsage = memoryUsageHistory.last else { return false }
            return currentUsage > pressureThreshold
        }

        func getMemoryTrend() -> MemoryTrend {
            guard memoryUsageHistory.count >= 3 else { return .stable }
            let recent = memoryUsageHistory.suffix(3)
            let differences = zip(recent, recent.dropFirst()).map { $1 - $0 }
            let trend = differences.reduce(0, +)

            if trend > 0 {
                return .increasing
            } else if trend < 0 {
                return .decreasing
            }
            return .stable
        }
    }

    private enum MemoryTrend {
        case increasing, stable, decreasing
    }

    private var mixtapeCacheManager: CacheManager<MixTape>!
    private var moodCacheManager: CacheManager<(mood: Mood, confidence: Float)>!
    private var memoryMonitor: MemoryMonitor!

    // MARK: - Performance Optimization

    private let performanceQueue = DispatchQueue(label: "siri.performance.queue", qos: .background)

    // MARK: - Initialization

    override init() {
        super.init()
        setupMemoryManagement()
    }

    deinit {
        // Cleanup
        cachePurgeTimer?.invalidate()
        memoryPressureTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func setupAutoCleanup() {
        // Set up periodic cache validation
        Timer.scheduledTimer(withTimeInterval: CacheConfig.cleanupInterval, repeats: true) { [weak self] _ in
            self?.validateCaches()
        }

        // Set up periodic performance logging
        if ProcessInfo.processInfo.environment["ENABLE_PERFORMANCE_LOGGING"] == "1" {
            Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                print(self?.logPerformanceMetrics() ?? "")
            }
        }
    }

    private func validateCaches() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            let now = Date()

            // Validate mixtape cache
            for (key, value) in mixtapeCacheManager.cache {
                if now.timeIntervalSince(value.timestamp) > CacheConfig.extendedExpiryInterval {
                    mixtapeCacheManager.cache.removeValue(forKey: key)
                }
            }

            // Validate mood cache
            for (key, value) in moodCacheManager.cache {
                if now.timeIntervalSince(value.timestamp) > CacheConfig.defaultExpiryInterval {
                    moodCacheManager.cache.removeValue(forKey: key)
                }
            }

            // Update last validation timestamp
            lastCacheUpdate = now
        }
    }

    // MARK: - Optimized Intent Handlers

    /// Fast play media intent handler with caching
    func handlePlayMediaIntent(_ intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        intentQueue.async { [weak self] in
            guard let self else {
                completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }

            let startTime = CFAbsoluteTimeGetCurrent()

            // Validate parameters
            guard validateIntent(intent) else {
                let response = INPlayMediaIntentResponse(code: .failure, userActivity: nil)
                response.errorDescription = NSLocalizedString(
                    "Invalid request parameters. Please try again.",
                    comment: ""
                )
                completion(response)
                return
            }

            // Fast path for cached results
            if let cachedResponse = getCachedPlayResponse(for: intent) {
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                cacheStats.hits += 1
                updateLatencyStats(elapsedTime * 1000) // Convert to ms
                completion(cachedResponse)
                return
            }

            cacheStats.misses += 1

            // Process intent with optimized flow and timeout
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                let response = INPlayMediaIntentResponse(code: .failure, userActivity: nil)
                response.errorDescription = NSLocalizedString("Request timed out. Please try again.", comment: "")
                self?.logLatencyViolation()
                completion(response)
            }

            processPlayMediaIntent(intent) { [weak self] response in
                timeoutTimer.invalidate()

                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                self?.updateLatencyStats(elapsedTime * 1000)

                // Cache successful responses
                if response.code == .success {
                    self?.cachePlayResponse(response, for: intent)
                }

                completion(response)
            }
        }
    }

    private func updateLatencyStats(_ latencyMs: Double) {
        performanceQueue.async {
            let total = self.cacheStats.hits + self.cacheStats.misses
            self.cacheStats.avgLatency = ((self.cacheStats.avgLatency * Double(total - 1)) + latencyMs) / Double(total)

            // Log violation if above threshold
            if latencyMs > 2000 { // 2 seconds
                self.logLatencyViolation()
            }
        }
    }

    private func logLatencyViolation() {
        NotificationCenter.default.post(
            name: Notification.Name("SiriIntentLatencyViolation"),
            object: nil,
            userInfo: ["avgLatency": cacheStats.avgLatency]
        )
    }

    // MARK: - Optimized Processing Methods

    private func processPlayMediaIntent(
        _ intent: INPlayMediaIntent,
        completion: @escaping (INPlayMediaIntentResponse) -> Void
    ) {
        Task {
            let spokenPhrase = intent.mediaSearch?.mediaName?.spokenPhrase?.lowercased() ?? ""

            // Try cache first
            if let (mood, confidence) = await getCachedMood(for: spokenPhrase) {
                await findOptimalMixtapeForMood(mood, confidence: confidence, completion: completion)
                return
            }

            // Extract mood and cache result
            let (mood, confidence) = extractMoodFromIntent(intent)
            await cacheMood(mood, confidence: confidence, for: spokenPhrase)
            await findOptimalMixtapeForMood(mood, confidence: confidence, completion: completion)
        }
    }

    private func findOptimalMixtapeForMood(
        _ mood: Mood,
        confidence _: Float,
        completion: @escaping (INPlayMediaIntentResponse) -> Void
    ) async {
        let cacheKey = "mood_\(mood.rawValue)"

        if let cachedMixtape = await getCachedMixtape(for: cacheKey) {
            let response = createSuccessResponse(with: cachedMixtape)
            completion(response)
            return
        }

        // Find best matching mixtape
        let request: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        request.predicate = NSPredicate(format: "moodTags CONTAINS[c] %@", mood.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "playCount", ascending: false)]
        request.fetchLimit = 1

        do {
            let mixtapes = try context.fetch(request)
            if let bestMixtape = mixtapes.first {
                await cacheMixtape(bestMixtape, for: cacheKey)
                let response = createSuccessResponse(with: bestMixtape)
                completion(response)
            } else {
                completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            }
        } catch {
            completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
        }
    }

    private func createSuccessResponse(with mixtape: MixTape) -> INPlayMediaIntentResponse {
        let mediaItem = createMediaItem(from: mixtape)
        let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
        response.nowPlayingInfo = [mediaItem]
        return response
    }

    private func processSearchMediaIntent(
        _ intent: INSearchForMediaIntent,
        completion: @escaping (INSearchForMediaIntentResponse) -> Void
    ) {
        let searchTerm = intent.mediaName?.spokenPhrase ?? ""
        let mood = extractMoodFromSearchTerm(searchTerm)

        // Use cached mixtapes for faster search
        searchCachedMixtapes(term: searchTerm, mood: mood) { [weak self] results in
            guard let self else {
                completion(INSearchForMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }

            let mediaItems = results.map { self.createMediaItem(from: $0) }
            let response = INSearchForMediaIntentResponse(code: .success, userActivity: nil)
            response.mediaItems = mediaItems

            completion(response)
        }
    }

    private func processAddMediaIntent(
        _ intent: INAddMediaIntent,
        completion: @escaping (INAddMediaIntentResponse) -> Void
    ) {
        guard let playlistName = intent.mediaDestination?.mediaName?.spokenPhrase else {
            completion(INAddMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }

        // Create mixtape efficiently using pre-computed settings
        createMixtapeEfficiently(name: playlistName) { [weak self] success in
            guard let self else {
                completion(INAddMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }

            let response = INAddMediaIntentResponse(code: success ? .success : .failure, userActivity: nil)

            if success {
                // Invalidate cache to include new mixtape
                invalidateCache()
            }

            completion(response)
        }
    }

    // MARK: - Optimized Helper Methods

    private func extractMoodFromIntent(_ intent: INPlayMediaIntent) -> (mood: Mood, confidence: Float) {
        // Extract spoken phrase efficiently
        let spokenPhrase = intent.mediaSearch?.mediaName?.spokenPhrase?.lowercased() ?? ""

        // Check cache first with minimum validity period
        if let cachedMood = moodCacheManager.get(spokenPhrase) {
            return (cachedMood.mood, cachedMood.confidence)
        }

        // Enhanced mood pattern matching with confidence scoring
        var moodScores: [(mood: Mood, confidence: Float)] = []

        // Direct keyword matches (highest confidence)
        let directMatches = DirectMoodMatchers.findDirectMatches(in: spokenPhrase)
        moodScores.append(contentsOf: directMatches)

        // Contextual pattern matches (medium confidence)
        let contextualMatches = ContextualMoodMatchers.findContextualMatches(in: spokenPhrase)
        moodScores.append(contentsOf: contextualMatches)

        // Analyze text sentiment for additional context (lower confidence)
        if let sentimentMood = analyzeSentiment(spokenPhrase) {
            moodScores.append(sentimentMood)
        }

        // Select best match with highest confidence
        if let bestMatch = moodScores.max(by: { $0.confidence < $1.confidence }) {
            // Cache the result
            moodCacheManager.set(spokenPhrase, value: CachedMood(
                mood: bestMatch.mood,
                timestamp: Date(),
                confidence: bestMatch.confidence,
                lastAccess: Date()
            ), cost: 1)
            return bestMatch
        }

        // Default to current mood with lower confidence if no matches
        let currentMood = moodEngine.currentMood
        let defaultResult = (Mood(rawValue: currentMood.rawValue) ?? .neutral, 0.5)

        // Cache default result
        moodCacheManager.set(spokenPhrase, value: CachedMood(
            mood: defaultResult.0,
            timestamp: Date(),
            confidence: defaultResult.1,
            lastAccess: Date()
        ), cost: 1)

        return defaultResult
    }

    private func extractMoodFromSearchTerm(_ searchTerm: String) -> Mood? {
        let lowercased = searchTerm.lowercased()

        let moodKeywords: [String: Mood] = [
            "energetic": .energetic,
            "relaxed": .relaxed,
            "happy": .happy,
            "focused": .focused,
            "romantic": .romantic,
            "angry": .angry,
            "melancholic": .melancholic,
        ]

        for (keyword, mood) in moodKeywords {
            if lowercased.contains(keyword) {
                return mood
            }
        }

        return nil
    }

    private func findOptimalMixtape(for mood: Mood, completion: @escaping (MixTape?) -> Void) {
        // Check cache first
        let cacheKey = "mood_\(mood.rawValue)"
        if let cachedMixtape = mixtapeCacheManager.get(cacheKey),
           Date().timeIntervalSince(lastCacheUpdate) < CacheConfig.defaultExpiryInterval
        {
            completion(cachedMixtape)
            return
        }

        // Fast Core Data query
        let request: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        request.predicate = NSPredicate(format: "moodTags CONTAINS[c] %@", mood.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "playCount", ascending: false)]
        request.fetchLimit = 1

        context.perform { [weak self] in
            do {
                let results = try self?.context.fetch(request) ?? []
                let mixtape = results.first

                // Cache the result
                if let mixtape {
                    self?.mixtapeCacheManager.set(
                        "mood_\(mood.rawValue)",
                        value: CachedMixtape(mixtape: mixtape, timestamp: Date(), accessCount: 1, lastAccess: Date()),
                        cost: 1
                    )
                }

                DispatchQueue.main.async {
                    completion(mixtape)
                }
            } catch {
                print("Error fetching mixtape: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    private func searchCachedMixtapes(term: String, mood: Mood?, completion: @escaping ([MixTape]) -> Void) {
        let request: NSFetchRequest<MixTape> = MixTape.fetchRequest()

        var predicates: [NSPredicate] = []

        if !term.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[c] %@", term))
        }

        if let mood {
            predicates.append(NSPredicate(format: "moodTags CONTAINS[c] %@", mood.rawValue))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [NSSortDescriptor(key: "playCount", ascending: false)]
        request.fetchLimit = 5 // Limit results for performance

        context.perform { [weak self] in
            do {
                let results = try self?.context.fetch(request) ?? []
                DispatchQueue.main.async {
                    completion(results)
                }
            } catch {
                print("Error searching mixtapes: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    private func createMixtapeEfficiently(name: String, completion: @escaping (Bool) -> Void) {
        context.perform { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let mixtape = MixTape(context: context)
            mixtape.title = name
            mixtape.aiGenerated = true
            mixtape.moodTags = moodEngine.currentMood.rawValue
            mixtape.numberOfSongs = 0

            do {
                try context.save()
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("Error creating mixtape: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    private func createMediaItem(from mixtape: MixTape) -> INMediaItem {
        let item = INMediaItem(
            identifier: mixtape.objectID.uriRepresentation().absoluteString,
            title: mixtape.wrappedTitle,
            type: .playlist,
            artwork: nil
        )
        return item
    }

    // MARK: - Caching Optimization

    private func getCachedPlayResponse(for intent: INPlayMediaIntent) -> INPlayMediaIntentResponse? {
        // Simple caching based on intent signature
        let signature = createIntentSignature(intent)

        // Check if we have a recent cached response
        if let cached = responseCacheSignatures[signature],
           Date().timeIntervalSince(cached.timestamp) < 60
        { // 1 minute cache
            return cached.response
        }

        return nil
    }

    private func cachePlayResponse(_ response: INPlayMediaIntentResponse, for intent: INPlayMediaIntent) {
        let signature = createIntentSignature(intent)
        responseCacheSignatures[signature] = CachedResponse(response: response, timestamp: Date())
    }

    private func createIntentSignature(_ intent: INPlayMediaIntent) -> String {
        let mediaName = intent.mediaSearch?.mediaName?.spokenPhrase ?? ""
        let reference = intent.mediaSearch?.reference?.rawValue ?? 0
        return "\(mediaName)_\(reference)"
    }

    private var responseCacheSignatures: [String: CachedResponse] = [:]

    private func preWarmCaches() async {
        // Pre-load frequently accessed mixtapes
        let request: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "playCount", ascending: false)]
        request.fetchLimit = 20

        do {
            let popularMixtapes = try context.fetch(request)

            // Cache by mood
            for mixtape in popularMixtapes {
                for moodTag in mixtape.moodTagsArray {
                    if let mood = Mood(rawValue: moodTag) {
                        let cacheKey = "mood_\(mood.rawValue)"
                        if mixtapeCacheManager.get(cacheKey) == nil {
                            mixtapeCacheManager.set(
                                cacheKey,
                                value: CachedMixtape(mixtape: mixtape, timestamp: Date(), accessCount: 1,
                                                     lastAccess: Date()),
                                cost: 1
                            )
                        }
                    }
                }
            }

            lastCacheUpdate = Date()
            print("SiriKit caches pre-warmed with \(popularMixtapes.count) mixtapes")
        } catch {
            print("Error pre-warming caches: \(error)")
        }
    }

    private func invalidateCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.mixtapeCacheManager.clear()
            self?.moodCacheManager.clear()
            self?.responseCacheSignatures.removeAll()
            self?.lastCacheUpdate = Date.distantPast
        }
    }

    // MARK: - Memory Management

    private func setupMemoryManagement() {
        mixtapeCacheManager = CacheManager<MixTape>(maxCost: CacheConfig.memoryPressureThreshold / 2)
        moodCacheManager = CacheManager<(mood: Mood, confidence: Float)>(maxCost: CacheConfig
            .memoryPressureThreshold / 4)
        memoryMonitor = MemoryMonitor()

        setupMemoryMonitoring()
    }

    private func setupMemoryMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // Periodic memory monitoring
        Timer.scheduledTimer(withTimeInterval: CacheConfig.cleanupInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.monitorMemory()
            }
        }
    }

    @objc private func handleMemoryPressure(_: Notification) {
        Task { [weak self] in
            // Perform aggressive cleanup
            await mixtapeCacheManager?.clear()
            await moodCacheManager?.clear()
            responseCacheSignatures.removeAll()

            // Log memory pressure event
            if let memoryUsage = self?.getCurrentMemoryUsage() {
                await memoryMonitor?.recordMemoryUsage(memoryUsage)
                NotificationCenter.default.post(
                    name: Notification.Name("SiriMemoryPressure"),
                    object: nil,
                    userInfo: ["memoryUsage": memoryUsage]
                )
            }
        }
    }

    private func monitorMemory() async {
        let currentUsage = getCurrentMemoryUsage()
        await memoryMonitor.recordMemoryUsage(currentUsage)

        if await memoryMonitor.shouldReduceMemory() {
            let trend = await memoryMonitor.getMemoryTrend()

            switch trend {
            case .increasing:
                // Aggressive cleanup
                await mixtapeCacheManager?.clear()
                await moodCacheManager?.clear()
                responseCacheSignatures.removeAll()

            case .stable:
                // Gradual cleanup - clear old items
                await performGradualCleanup()

            case .decreasing:
                // Light cleanup - just update stats
                updateMemoryMetrics(usage: currentUsage)
            }
        }
    }

    private func performGradualCleanup() async {
        // Remove expired items and update metrics
        responseCacheSignatures = responseCacheSignatures.filter {
            $0.value.timestamp.timeIntervalSinceNow > -CacheConfig.defaultExpiryInterval
        }
    }

    private func updateMemoryMetrics(usage: Int) {
        performanceQueue.async {
            self.performanceMetrics.memoryUsage = Int64(usage)
            self.performanceMetrics.cacheSize = self.responseCacheSignatures.count
        }
    }

    // MARK: - Enhanced Performance Monitoring

    private struct PerformanceMetrics {
        var cacheHitRate: Double = 0
        var averageResponseTime: Double = 0
        var p95ResponseTime: Double = 0
        var p99ResponseTime: Double = 0
        var cacheSize: Int = 0
        var memoryUsage: Int64 = 0
        var errorCount: Int = 0
        var totalRequests: Int = 0
        var activeRequests: Int = 0

        mutating func updateResponseTimes(_ times: [TimeInterval]) {
            guard !times.isEmpty else { return }
            let sortedTimes = times.sorted()
            averageResponseTime = times.reduce(0, +) / Double(times.count)
            p95ResponseTime = sortedTimes[Int(Double(times.count) * 0.95)]
            p99ResponseTime = sortedTimes[Int(Double(times.count) * 0.99)]
        }

        var description: String {
            """
            SiriKit Performance Metrics:
            - Requests: \(totalRequests) (Active: \(activeRequests))
            - Cache Hit Rate: \(String(format: "%.1f%%", cacheHitRate * 100))
            - Response Times (ms):
              • Average: \(String(format: "%.2f", averageResponseTime * 1000))
              • P95: \(String(format: "%.2f", p95ResponseTime * 1000))
              • P99: \(String(format: "%.2f", p99ResponseTime * 1000))
            - Cache Size: \(cacheSize) items
            - Memory Usage: \(memoryUsage / 1024 / 1024)MB
            - Errors: \(errorCount)
            """
        }
    }

    // MARK: - Enhanced Cache Management

    private func performCacheCleanup() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            let now = Date()

            // Clear expired items
            clearExpiredCaches()

            // Enforce memory limits
            let currentMemory = getCurrentMemoryUsage()
            if Double(currentMemory) / 1024 / 1024 > 50 { // Over 50MB
                reduceCacheSize(targetSize: maxCacheSize / 2)
            } else if mixtapeCacheManager.cache.count > maxCacheSize {
                reduceCacheSize(targetSize: maxCacheSize)
            }

            // Update metrics
            performanceMetrics.cacheSize = mixtapeCacheManager.cache.count
            updateMemoryUsage()
        }
    }

    private func reduceCacheSize(targetSize: Int) {
        // Sort items by access count and recency
        let sortedItems = mixtapeCacheManager.cache.sorted { item1, item2 in
            // Compare access counts first
            if item1.value.accessCount != item2.value.accessCount {
                return item1.value.accessCount > item2.value.accessCount
            }
            // If equal access counts, compare last access time
            return item1.value.lastAccess > item2.value.lastAccess
        }

        // Keep only most relevant items
        if sortedItems.count > targetSize {
            let itemsToKeep = Dictionary(
                uniqueKeysWithValues: sortedItems.prefix(targetSize)
            )
            mixtapeCacheManager.cache = itemsToKeep
        }

        // Update tracking
        itemAgeTracking = itemAgeTracking.filter { key, _ in
            mixtapeCacheManager.cache.keys.contains(key)
        }
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    private func logPerformanceMetrics() -> String {
        performanceQueue.sync {
            performanceMetrics.description
        }
    }

    private func updateMemoryUsage() {
        let memory = getCurrentMemoryUsage()
        performanceQueue.async {
            self.performanceMetrics.memoryUsage = Int64(memory)
        }
    }

    // MARK: - Enhanced Request Tracking

    private func trackRequestStart() {
        performanceQueue.async {
            self.performanceMetrics.totalRequests += 1
            self.performanceMetrics.activeRequests += 1
        }
    }

    private func trackRequestEnd(responseTime: TimeInterval, cacheHit: Bool) {
        performanceQueue.async {
            self.performanceMetrics.activeRequests -= 1

            // Update response times
            self.responseTimes.append(responseTime)
            if self.responseTimes.count > self.maxResponseTimes {
                self.responseTimes.removeFirst()
            }

            // Update cache stats
            if cacheHit {
                self.cacheStats.hits += 1
            } else {
                self.cacheStats.misses += 1
            }

            let total = Double(self.cacheStats.hits + self.cacheStats.misses)
            self.performanceMetrics.cacheHitRate = Double(self.cacheStats.hits) / total
            self.performanceMetrics.updateResponseTimes(self.responseTimes)
        }
    }
}

// MARK: - Enhanced Intent Handling

extension OptimizedSiriIntentService: INPlayMediaIntentHandling {
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        handlePlayMediaIntent(intent, completion: completion)
    }

    func resolveMediaItems(
        for intent: INPlayMediaIntent,
        with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void
    ) {
        // Fast resolution using cached data
        let mood = extractMoodFromIntent(intent)

        findOptimalMixtape(for: mood) { mixtape in
            if let mixtape {
                let mediaItem = self.createMediaItem(from: mixtape)
                completion([INPlayMediaMediaItemResolutionResult.success(with: mediaItem)])
            } else {
                completion([INPlayMediaMediaItemResolutionResult.unsupported()])
            }
        }
    }
}

extension OptimizedSiriIntentService: INSearchForMediaIntentHandling {
    func handle(intent: INSearchForMediaIntent, completion: @escaping (INSearchForMediaIntentResponse) -> Void) {
        handleSearchMediaIntent(intent, completion: completion)
    }
}

extension OptimizedSiriIntentService: INAddMediaIntentHandling {
    func handle(intent: INAddMediaIntent, completion: @escaping (INAddMediaIntentResponse) -> Void) {
        handleAddMediaIntent(intent, completion: completion)
    }
}

// MARK: - Localized Error Handling

private enum LocalizedError {
    static let invalidParameters = NSLocalizedString(
        "The request parameters are invalid. Please try adjusting your command.",
        comment: ""
    )
    static let timeout = NSLocalizedString("The request took too long to process. Please try again.", comment: "")
    static let noMixtapes = NSLocalizedString("No mixtapes found matching your mood.", comment: "")
    static let systemError = NSLocalizedString("Something went wrong. Please try again.", comment: "")
    static let cacheMiss = NSLocalizedString(
        "Unable to find matching music quickly. Generating new recommendations.",
        comment: ""
    )
}

private func createErrorResponse(_ error: Error) -> INPlayMediaIntentResponse {
    let response = INPlayMediaIntentResponse(code: .failure, userActivity: nil)

    switch error {
    case let intentError as IntentError:
        response.errorDescription = getLocalizedDescription(for: intentError)
    case let validationError as ValidationError:
        response.errorDescription = getLocalizedDescription(for: validationError)
    default:
        response.errorDescription = LocalizedError.systemError
    }

    return response
}

private func getLocalizedDescription(for error: IntentError) -> String {
    switch error {
    case .invalidParameters:
        LocalizedError.invalidParameters
    case .processingTimeout:
        LocalizedError.timeout
    case .noResults:
        LocalizedError.noMixtapes
    case .systemError:
        LocalizedError.systemError
    }
}

private func getLocalizedDescription(for error: ValidationError) -> String {
    switch error {
    case .invalidSongCount:
        NSLocalizedString("Please request between 1 and 50 songs.", comment: "")
    case .invalidMood:
        NSLocalizedString(
            "I didn't understand that mood. Try something like happy, relaxed, or energetic.",
            comment: ""
        )
    case .invalidSearchTerm:
        NSLocalizedString("Please provide a longer search term.", comment: "")
    }
}

enum IntentError: Error {
    case invalidParameters
    case processingTimeout
    case noResults
    case systemError
}

enum ValidationError: Error {
    case invalidSongCount
    case invalidMood
    case invalidSearchTerm
}

// MARK: - Memory Management

private func handleMemoryPressure(_: Notification) {
    // Aggressively clear caches under memory pressure
    intentQueue.async(flags: .barrier) {
        self.mixtapeCacheManager.clear()
        self.moodCacheManager.clear()
        self.responseCacheSignatures.removeAll()
    }
}
