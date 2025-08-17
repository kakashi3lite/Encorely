//
//  MixTapeModels.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AppKit
import CoreData
import Foundation
import Domain
import SharedTypes

// Import the CoreData class definitions
// Note: MixTape and Song classes are defined in their respective +CoreDataClass.swift files

// Type aliases for protocol conformance
typealias MixTape = any MixTapeProtocol
typealias Song = any SongProtocol

/// Extension for MixTape that adds AI-related functionality
extension MixTapeProtocol {
    // This file contains implementations of the protocol methods defined in CoreDataProtocols.swift
    // The actual implementations are in CoreDataProtocols.swift to avoid duplication
}

// MARK: - Song Extension

extension SongProtocol {
    // This file contains implementations of the protocol methods defined in CoreDataProtocols.swift
    // The actual implementations are in CoreDataProtocols.swift to avoid duplication
}
