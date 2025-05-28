//
//  OptimizedSiriIntentService.swift
//  Mixtapes
//
//  Optimized SiriKit intent handling for better performance
//  Fixes ISSUE-010: SiriKit Intent Extension Optimization
//

import Foundation
import Intents
import CoreData
import Combine

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
    private let maxCacheSize = 100 // Maximum number of cached items
    private var itemAgeTracking: [String: Date] = [:] // Track age of cached items
    
    // MARK: - Caching
    private var mixtapeCache: [String: CachedMixtape] = [:]
    private var moodCache: [String: CachedMood] = [:]
    private var lastCacheUpdate = Date()
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    private let memoryCacheExpiryInterval: TimeInterval = 600 // 10 minutes
    
    // Memory-efficient cache structures
    private struct CachedMixtape {
        let mixtape: MixTape
        let timestamp: Date
        let accessCount: Int
    }
    
    private struct CachedMood {
        let mood: Mood
        let timestamp: Date
        let confidence: Float
    }
    
    // MARK: - Response Templates (Pre-computed)
    private lazy var responseTemplates: [String: INSpeakableString] = {
        return [
            "play_energetic": INSpeakableString(spokenPhrase: "Playing energetic music"),
            "play_relaxed": INSpeakableString(spokenPhrase: "Playing relaxing music"),
            "play_happy": INSpeakableString(spokenPhrase: "Playing happy music"),
            "play_focused": INSpeakableString(spokenPhrase: "Playing focus music"),
            "play_romantic": INSpeakableString(spokenPhrase: "Playing romantic music"),
            "create_success": INSpeakableString(spokenPhrase: "Mixtape created successfully"),
            "search_found": INSpeakableString(spokenPhrase: "Found your mixtape"),
            "no_results": INSpeakableString(spokenPhrase: "No mixtapes found")
        ]
    }()
    
    // MARK: - Initialization
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine, context: NSManagedObjectContext) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        self.context = context
        super.init()
        
        // Setup performance monitoring
        self.performanceQueue = DispatchQueue(label: "siri.performance", qos: .utility)
        
        // Setup memory management
        setupMemoryPressureHandling()
        
        // Pre-warm caches
        Task {
            await preWarmCaches()
        }
        
        // Setup auto-cleanup
        setupAutoCleanup()
    }
    
    deinit {
        // Cleanup
        cachePurgeTimer?.invalidate()
        memoryPressureTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAutoCleanup() {
        // Set up periodic cache validation
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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
            guard let self = self else { return }
            
            let now = Date()
            
            // Validate mixtape cache
            for (key, value) in self.mixtapeCache {
                if now.timeIntervalSince(value.timestamp) > self.memoryCacheExpiryInterval {
                    self.mixtapeCache.removeValue(forKey: key)
                }
            }
            
            // Validate mood cache
            for (key, value) in self.moodCache {
                if now.timeIntervalSince(value.timestamp) > self.cacheExpiryInterval {
                    self.moodCache.removeValue(forKey: key)
                }
            }
            
            // Update last validation timestamp
            self.lastCacheUpdate = now
        }
    }
    
    // MARK: - Performance Optimization
    private let performanceQueue = DispatchQueue(label: "siri.performance.queue", qos: .background)
    
    // MARK: - Memory Management
    private var memoryPressureTask: Task<Void, Never>?
    private var cachePurgeTimer: Timer?
    private let maxCacheSize = 100 // Maximum number of cached items
    private var itemAgeTracking: [String: Date] = [:] // Track age of cached items
    
    // MARK: - Caching
    private var mixtapeCache: [String: CachedMixtape] = [:]
    private var moodCache: [String: CachedMood] = [:]
    private var lastCacheUpdate = Date()
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    private let memoryCacheExpiryInterval: TimeInterval = 600 // 10 minutes
    
    // Memory-efficient cache structures
    private struct CachedMixtape {
        let mixtape: MixTape
        let timestamp: Date
        let accessCount: Int
    }
    
    private struct CachedMood {
        let mood: Mood
        let timestamp: Date
        let confidence: Float
    }
    
    // MARK: - Response Templates (Pre-computed)
    private lazy var responseTemplates: [String: INSpeakableString] = {
        return [
            "play_energetic": INSpeakableString(spokenPhrase: "Playing energetic music"),
            "play_relaxed": INSpeakableString(spokenPhrase: "Playing relaxing music"),
            "play_happy": INSpeakableString(spokenPhrase: "Playing happy music"),
            "play_focused": INSpeakableString(spokenPhrase: "Playing focus music"),
            "play_romantic": INSpeakableString(spokenPhrase: "Playing romantic music"),
            "create_success": INSpeakableString(spokenPhrase: "Mixtape created successfully"),
            "search_found": INSpeakableString(spokenPhrase: "Found your mixtape"),
            "no_results": INSpeakableString(spokenPhrase: "No mixtapes found")
        ]
    }()
    
    // MARK: - Initialization
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine, context: NSManagedObjectContext) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        self.context = context
        super.init()
        
        // Setup performance monitoring
        self.performanceQueue = DispatchQueue(label: "siri.performance", qos: .utility)
        
        // Setup memory management
        setupMemoryPressureHandling()
        
        // Pre-warm caches
        Task {
            await preWarmCaches()
        }
        
        // Setup auto-cleanup
        setupAutoCleanup()
    }
    
    deinit {
        // Cleanup
        cachePurgeTimer?.invalidate()
        memoryPressureTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAutoCleanup() {
        // Set up periodic cache validation
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
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
            guard let self = self else { return }
            
            let now = Date()
            
            // Validate mixtape cache
            for (key, value) in self.mixtapeCache {
                if now.timeIntervalSince(value.timestamp) > self.memoryCacheExpiryInterval {
                    self.mixtapeCache.removeValue(forKey: key)
                }
            }
            
            // Validate mood cache
            for (key, value) in self.moodCache {
                if now.timeIntervalSince(value.timestamp) > self.cacheExpiryInterval {
                    self.moodCache.removeValue(forKey: key)
                }
            }
            
            // Update last validation timestamp
            self.lastCacheUpdate = now
        }
    }
    
    // MARK: - Optimized Intent Handlers
    
    /// Fast play media intent handler with caching
    func handlePlayMediaIntent(_ intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        intentQueue.async { [weak self] in
            guard let self = self else {
                completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Fast path for cached results
            if let cachedResponse = self.getCachedPlayResponse(for: intent) {
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                print("SiriKit Play Intent handled in \(elapsedTime * 1000)ms (cached)")
                completion(cachedResponse)
                return
            }
            
            // Process intent with optimized flow
            self.processPlayMediaIntent(intent) { response in
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                print("SiriKit Play Intent handled in \(elapsedTime * 1000)ms")
                completion(response)
            }
        }
    }
    
    /// Fast search media intent handler
    func handleSearchMediaIntent(_ intent: INSearchForMediaIntent, completion: @escaping (INSearchForMediaIntentResponse) -> Void) {
        intentQueue.async { [weak self] in
            guard let self = self else {
                completion(INSearchForMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            self.processSearchMediaIntent(intent) { response in
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                print("SiriKit Search Intent handled in \(elapsedTime * 1000)ms")
                completion(response)
            }
        }
    }
    
    /// Fast add media intent handler
    func handleAddMediaIntent(_ intent: INAddMediaIntent, completion: @escaping (INAddMediaIntentResponse) -> Void) {
        intentQueue.async { [weak self] in
            guard let self = self else {
                completion(INAddMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            self.processAddMediaIntent(intent) { response in
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                print("SiriKit Add Intent handled in \(elapsedTime * 1000)ms")
                completion(response)
            }
        }
    }
    
    // MARK: - Optimized Processing Methods
    
    private func processPlayMediaIntent(_ intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        // Extract mood from intent efficiently
        let detectedMood = extractMoodFromIntent(intent)
        
        // Find matching mixtape using cached data
        findOptimalMixtape(for: detectedMood) { [weak self] mixtape in
            guard let self = self else {
                completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }
            
            if let mixtape = mixtape {
                // Create optimized response
                let mediaItem = self.createMediaItem(from: mixtape)
                let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
                response.nowPlayingInfo = [mediaItem]
                
                // Cache successful response
                self.cachePlayResponse(response, for: intent)
                
                completion(response)
            } else {
                // Handle no results case
                let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
                completion(response)
            }
        }
    }
    
    private func processSearchMediaIntent(_ intent: INSearchForMediaIntent, completion: @escaping (INSearchForMediaIntentResponse) -> Void) {
        let searchTerm = intent.mediaName?.spokenPhrase ?? ""
        let mood = extractMoodFromSearchTerm(searchTerm)
        
        // Use cached mixtapes for faster search
        searchCachedMixtapes(term: searchTerm, mood: mood) { [weak self] results in
            guard let self = self else {
                completion(INSearchForMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }
            
            let mediaItems = results.map { self.createMediaItem(from: $0) }
            let response = INSearchForMediaIntentResponse(code: .success, userActivity: nil)
            response.mediaItems = mediaItems
            
            completion(response)
        }
    }
    
    private func processAddMediaIntent(_ intent: INAddMediaIntent, completion: @escaping (INAddMediaIntentResponse) -> Void) {
        guard let playlistName = intent.mediaDestination?.mediaName?.spokenPhrase else {
            completion(INAddMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Create mixtape efficiently using pre-computed settings
        createMixtapeEfficiently(name: playlistName) { [weak self] success in
            guard let self = self else {
                completion(INAddMediaIntentResponse(code: .failure, userActivity: nil))
                return
            }
            
            let response = INAddMediaIntentResponse(code: success ? .success : .failure, userActivity: nil)
            
            if success {
                // Invalidate cache to include new mixtape
                self.invalidateCache()
            }
            
            completion(response)
        }
    }
    
    // MARK: - Optimized Helper Methods
    
    private func extractMoodFromIntent(_ intent: INPlayMediaIntent) -> (mood: Mood, confidence: Float) {
        // Extract spoken phrase efficiently
        let spokenPhrase = intent.mediaSearch?.mediaName?.spokenPhrase?.lowercased() ?? ""
        
        // Check cache first with minimum validity period
        if let cachedMood = moodCache[spokenPhrase], 
           Date().timeIntervalSince(cachedMood.timestamp) < cacheExpiryInterval {
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
            moodCache[spokenPhrase] = CachedMood(
                mood: bestMatch.mood,
                timestamp: Date(),
                confidence: bestMatch.confidence
            )
            return bestMatch
        }
        
        // Default to current mood with lower confidence if no matches
        let currentMood = moodEngine.currentMood
        let defaultResult = (Mood(rawValue: currentMood.rawValue) ?? .neutral, 0.5)
        
        // Cache default result
        moodCache[spokenPhrase] = CachedMood(
            mood: defaultResult.0,
            timestamp: Date(),
            confidence: defaultResult.1
        )
        
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
            "melancholic": .melancholic
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
        if let cachedMixtape = mixtapeCache[cacheKey]?.mixtape,
           Date().timeIntervalSince(lastCacheUpdate) < cacheExpiryInterval {
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
                if let mixtape = mixtape {
                    self?.mixtapeCache[cacheKey] = CachedMixtape(mixtape: mixtape, timestamp: Date(), accessCount: 1)
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
        
        if let mood = mood {
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
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let mixtape = MixTape(context: self.context)
            mixtape.title = name
            mixtape.aiGenerated = true
            mixtape.moodTags = self.moodEngine.currentMood.rawValue
            mixtape.numberOfSongs = 0
            
            do {
                try self.context.save()
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
           Date().timeIntervalSince(cached.timestamp) < 60 { // 1 minute cache
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
    
    private struct CachedResponse {
        let response: INPlayMediaIntentResponse
        let timestamp: Date
    }
    
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
                        if mixtapeCache[cacheKey] == nil {
                            mixtapeCache[cacheKey] = CachedMixtape(mixtape: mixtape, timestamp: Date(), accessCount: 1)
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
            self?.mixtapeCache.removeAll()
            self?.moodCache.removeAll()
            self?.responseCacheSignatures.removeAll()
            self?.lastCacheUpdate = Date.distantPast
        }
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryPressureHandling() {
        // Monitor memory pressure notifications
        NotificationCenter.default.addObserver(self, 
            selector: #selector(handleMemoryPressure),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
        
        // Set up periodic cache cleanup
        cachePurgeTimer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            self?.performCacheCleanup()
        }
    }

    @objc private func handleMemoryPressure(_ notification: Notification) {
        // Cancel any pending memory pressure task
        memoryPressureTask?.cancel()
        
        // Create new task for memory pressure handling
        memoryPressureTask = Task { [weak self] in
            // Clear expired caches immediately
            self?.clearExpiredCaches()
            
            // Reduce cache size aggressively
            self?.reduceCacheSize(targetSize: maxCacheSize / 2)
            
            // Clear response signatures
            self?.responseCacheSignatures.removeAll()
        }
    }

    private func performCacheCleanup() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear expired items
            self.clearExpiredCaches()
            
            // Maintain cache size limit
            if self.mixtapeCache.count > self.maxCacheSize {
                self.reduceCacheSize(targetSize: self.maxCacheSize)
            }
        }
    }

    private func clearExpiredCaches() {
        let now = Date()
        
        // Clear expired mixtapes
        mixtapeCache = mixtapeCache.filter { key, value in
            now.timeIntervalSince(value.timestamp) < memoryCacheExpiryInterval
        }
        
        // Clear expired moods
        moodCache = moodCache.filter { key, value in
            now.timeIntervalSince(value.timestamp) < memoryCacheExpiryInterval
        }
        
        // Clear expired response signatures
        responseCacheSignatures = responseCacheSignatures.filter { key, value in
            now.timeIntervalSince(value.timestamp) < cacheExpiryInterval
        }
    }

    private func reduceCacheSize(targetSize: Int) {
        // Sort items by access count and recency
        let sortedItems = mixtapeCache.sorted { item1, item2 in
            // Compare access counts first
            if item1.value.accessCount != item2.value.accessCount {
                return item1.value.accessCount > item2.value.accessCount
            }
            // If equal access counts, compare timestamps
            return item1.value.timestamp > item2.value.timestamp
        }
        
        // Keep only the most relevant items
        if sortedItems.count > targetSize {
            let itemsToKeep = Array(sortedItems.prefix(targetSize))
            mixtapeCache = Dictionary(uniqueKeysWithValues: itemsToKeep)
        }
        
        // Update tracking
        itemAgeTracking = itemAgeTracking.filter { key, _ in
            mixtapeCache.keys.contains(key)
        }
    }
    
    // MARK: - Performance Monitoring
    
    struct PerformanceMetrics {
        var cacheHitRate: Double
        var averageResponseTime: TimeInterval
        var cacheSize: Int
        var memoryUsage: Int64
        var errorCount: Int
        
        var description: String {
            """
            SiriKit Performance Metrics:
            - Cache Hit Rate: \(String(format: "%.1f%%", cacheHitRate * 100))
            - Avg Response Time: \(String(format: "%.2fms", averageResponseTime * 1000))
            - Cache Size: \(cacheSize) items
            - Memory Usage: \(memoryUsage / 1024 / 1024)MB
            - Error Count: \(errorCount)
            """
        }
    }

    private var performanceMetrics = PerformanceMetrics(
        cacheHitRate: 0,
        averageResponseTime: 0,
        cacheSize: 0,
        memoryUsage: 0,
        errorCount: 0
    )

    private var totalRequests: Int = 0
    private var cacheHits: Int = 0
    private var responseTimes: [TimeInterval] = []
    private let maxResponseTimes = 100 // Keep last 100 response times

    private func trackPerformance(operation: String, startTime: CFAbsoluteTime, cacheHit: Bool) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let responseTime = endTime - startTime
        
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Update metrics
            self.totalRequests += 1
            if cacheHit { self.cacheHits += 1 }
            
            // Update response times
            self.responseTimes.append(responseTime)
            if self.responseTimes.count > self.maxResponseTimes {
                self.responseTimes.removeFirst()
            }
            
            // Update performance metrics
            self.performanceMetrics.cacheHitRate = Double(self.cacheHits) / Double(self.totalRequests)
            self.performanceMetrics.averageResponseTime = self.responseTimes.reduce(0, +) / Double(self.responseTimes.count)
            self.performanceMetrics.cacheSize = self.mixtapeCache.count + self.moodCache.count
            
            // Get memory usage
            self.updateMemoryUsage()
            
            // Log operation performance
            print("SiriKit \(operation) completed in \(String(format: "%.2fms", responseTime * 1000)) (Cache: \(cacheHit ? "HIT" : "MISS"))")
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            performanceMetrics.memoryUsage = Int64(info.resident_size)
        }
    }

    func logPerformanceMetrics() -> String {
        return performanceMetrics.description
    }
}

// MARK: - Enhanced Intent Handling

extension OptimizedSiriIntentService: INPlayMediaIntentHandling {
    
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        handlePlayMediaIntent(intent, completion: completion)
    }
    
    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        // Fast resolution using cached data
        let mood = extractMoodFromIntent(intent)
        
        findOptimalMixtape(for: mood) { mixtape in
            if let mixtape = mixtape {
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
