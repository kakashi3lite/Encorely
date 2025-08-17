//
//  GenerateMixtapeView.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI

struct GenerateMixtapeView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    
    // MARK: - State
    @State private var showingSuccessAlert = false
    @State private var generatedMixtape: Mixtape?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            GenerateView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
        .onReceive(mixtapeStore.$currentMixtape) { mixtape in
            if let mixtape = mixtape, generatedMixtape?.id != mixtape.id {
                generatedMixtape = mixtape
                showingSuccessAlert = true
            }
        }
        .alert("Mixtape Generated!", isPresented: $showingSuccessAlert) {
            Button("Play Now") {
                dismiss()
                // The mixtape is already set as current in the store
            }
            Button("View Library") {
                dismiss()
            }
        } message: {
            if let mixtape = generatedMixtape {
                Text("\"\(mixtape.name)\" has been created with \(mixtape.songCount) songs.")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GenerateMixtapeView()
        .environmentObject(MixtapeStore.preview)
        .environmentObject(AppState())
        .environmentObject(MusicAuthorizationManager.preview)
}