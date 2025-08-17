//
//  MusicAuthorizationManager.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit
import Combine

/// Manages Apple Music authorization and subscription status
class MusicAuthorizationManager: ObservableObject {
    // MARK: - Published Properties
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var isAuthorized = false
    @Published var hasActiveSubscription = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        checkAuthorizationStatus()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Request authorization for Apple Music
    @MainActor
    func requestAuthorization() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let status = await MusicAuthorization.request()
            updateAuthorizationStatus(status)
            
            if status == .authorized {
                await checkSubscriptionStatus()
            }
        } catch {
            errorMessage = "Failed to request music authorization: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Check current authorization status
    @MainActor
    func checkAuthorizationStatus() {
        let status = MusicAuthorization.currentStatus
        updateAuthorizationStatus(status)
        
        if status == .authorized {
            Task {
                await checkSubscriptionStatus()
            }
        }
    }
    
    /// Check if user has an active Apple Music subscription
    @MainActor
    private func checkSubscriptionStatus() async {
        do {
            let subscription = try await MusicSubscription.current
            hasActiveSubscription = subscription.canPlayCatalogContent
        } catch {
            hasActiveSubscription = false
            errorMessage = "Failed to check subscription status: \(error.localizedDescription)"
        }
    }
    
    /// Update authorization status and derived properties
    private func updateAuthorizationStatus(_ status: MusicAuthorization.Status) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = status == .authorized
        }
    }
    
    /// Setup observers for authorization changes
    private func setupObservers() {
        // Monitor authorization status changes
        NotificationCenter.default
            .publisher(for: .musicAuthorizationStatusDidChange)
            .sink { [weak self] _ in
                self?.checkAuthorizationStatus()
            }
            .store(in: &cancellables)
    }
    
    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }
    
    /// Get user-friendly status message
    var statusMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Music access not determined"
        case .denied:
            return "Music access denied. Please enable in Settings."
        case .restricted:
            return "Music access restricted"
        case .authorized:
            if hasActiveSubscription {
                return "Apple Music ready"
            } else {
                return "Apple Music subscription required"
            }
        @unknown default:
            return "Unknown authorization status"
        }
    }
    
    /// Check if the app can play music
    var canPlayMusic: Bool {
        return isAuthorized && hasActiveSubscription
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let musicAuthorizationStatusDidChange = Notification.Name("musicAuthorizationStatusDidChange")
}

// MARK: - Preview Support
#if DEBUG
extension MusicAuthorizationManager {
    static var preview: MusicAuthorizationManager {
        let manager = MusicAuthorizationManager()
        manager.isAuthorized = true
        manager.hasActiveSubscription = true
        return manager
    }
    
    static var previewUnauthorized: MusicAuthorizationManager {
        let manager = MusicAuthorizationManager()
        manager.isAuthorized = false
        manager.hasActiveSubscription = false
        return manager
    }
}
#endif