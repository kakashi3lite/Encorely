// filepath: Sources/App/Consolidated/LiveActivity/NowMixingActivity.swift
import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct NowMixingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var mood: String
        public var nextETASeconds: Int
        public init(mood: String, nextETASeconds: Int) { self.mood = mood; self.nextETASeconds = nextETASeconds }
    }
    public var title: String
    public init(title: String) { self.title = title }
}
#endif
