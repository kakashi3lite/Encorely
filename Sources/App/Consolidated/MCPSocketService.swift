import Combine
import Foundation
import SocketIO

// Event types for Socket.IO events
enum MCPEvent: String {
    case personalityHover = "personality:hover"
    case personalityStateUpdate = "personality:stateUpdate"
    case personalitySelect = "personality:select"
    case moodSelect = "mood:select"
    case moodStateUpdate = "mood:stateUpdate"
    case playerTogglePlayback = "player:togglePlayback"
    case playerSeek = "player:seek"
    case playerVolume = "player:volume"
    case playerToggleMute = "player:toggleMute"
    case playerStateUpdate = "player:stateUpdate"
}

// Protocols for component events
protocol MCPEventData: Codable {}

struct PersonalityEventData: MCPEventData {
    let type: String
    let traits: [String]
    let strength: Double
    let active: Bool?
    let hovered: Bool?
}

struct MoodEventData: MCPEventData {
    let type: String
    let intensity: Double
    let color: String
    let active: Bool?
}

struct PlayerEventData: MCPEventData {
    let type: String
    let time: Double?
    let level: Double?
}

class MCPSocketService: ObservableObject {
    private var manager: SocketManager
    private var socket: SocketIOClient

    // Publishers for component state updates
    @Published var personalityState: PersonalityEventData?
    @Published var moodState: MoodEventData?
    @Published var playerState: PlayerEventData?

    init() {
        // Initialize Socket.IO manager and client
        let serverURL = URL(string: "http://localhost:3000")!
        manager = SocketManager(socketURL: serverURL, config: [.log(true)])
        socket = manager.defaultSocket

        // Setup event handlers
        setupEventHandlers()
    }

    private func setupEventHandlers() {
        // Personality events
        socket.on(MCPEvent.personalityStateUpdate.rawValue) { [weak self] data, _ in
            guard let eventData = try? self?.decodeEventData(data, type: PersonalityEventData.self) else { return }
            DispatchQueue.main.async {
                self?.personalityState = eventData
            }
        }

        // Mood events
        socket.on(MCPEvent.moodStateUpdate.rawValue) { [weak self] data, _ in
            guard let eventData = try? self?.decodeEventData(data, type: MoodEventData.self) else { return }
            DispatchQueue.main.async {
                self?.moodState = eventData
            }
        }

        // Player events
        socket.on(MCPEvent.playerStateUpdate.rawValue) { [weak self] data, _ in
            guard let eventData = try? self?.decodeEventData(data, type: PlayerEventData.self) else { return }
            DispatchQueue.main.async {
                self?.playerState = eventData
            }
        }
    }

    // Helper function to decode event data
    private func decodeEventData<T: MCPEventData>(_ data: [Any], type _: T.Type) throws -> T {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data[0]) else {
            throw NSError(domain: "MCPSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid event data"])
        }
        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    // MARK: - Public Methods

    func connect() {
        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
    }

    // Personality events
    func emitPersonalityHover(type: String, hovered: Bool) {
        socket.emit(MCPEvent.personalityHover.rawValue, ["type": type, "hovered": hovered])
    }

    func emitPersonalitySelect(type: String) {
        socket.emit(MCPEvent.personalitySelect.rawValue, ["type": type])
    }

    // Mood events
    func emitMoodSelect(type: String) {
        socket.emit(MCPEvent.moodSelect.rawValue, ["type": type])
    }

    // Player events
    func emitPlayerTogglePlayback() {
        socket.emit(MCPEvent.playerTogglePlayback.rawValue)
    }

    func emitPlayerSeek(time: Double) {
        socket.emit(MCPEvent.playerSeek.rawValue, ["time": time])
    }

    func emitPlayerVolume(level: Double) {
        socket.emit(MCPEvent.playerVolume.rawValue, ["level": level])
    }

    func emitPlayerToggleMute() {
        socket.emit(MCPEvent.playerToggleMute.rawValue)
    }
}
