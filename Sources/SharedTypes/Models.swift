//
//  Models.swift
//  SharedTypes
//
//  Created by AI-Mixtapes Supercoder
//

import Foundation

// MARK: - AudioFeatures

// Simplified AudioFeatures definition for SharedTypes module
// Full implementation is in App/Consolidated/AudioFeatures.swift
public struct AudioFeatures: Codable {
    public let tempo: Float
    public let energy: Float
    public let valence: Float
    public let danceability: Float
    public let acousticness: Float
    public let instrumentalness: Float
    public let speechiness: Float
    public let liveness: Float

    public init(
        tempo: Float,
        energy: Float,
        valence: Float,
        danceability: Float,
        acousticness: Float,
        instrumentalness: Float,
        speechiness: Float,
        liveness: Float
    ) {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.danceability = danceability
        self.acousticness = acousticness
        self.instrumentalness = instrumentalness
        self.speechiness = speechiness
        self.liveness = liveness
    }
}

public protocol MixTapeModel {
    var title: String { get }
    var numberOfSongs: Int { get }
    var moodTags: [String] { get }
    var audioFeatures: [String: AudioFeatures] { get }
    var songs: [SongModel] { get }
}

public protocol SongModel {
    var name: String { get }
    var duration: TimeInterval { get }
    var url: URL { get }
    var audioFeatures: AudioFeatures? { get }
    var moodTag: String? { get }
}
