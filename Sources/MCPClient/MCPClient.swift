import SwiftUI
import Combine
import SocketIO

public class MCPClient: ObservableObject {
    private let manager: SocketManager
    private let socket: SocketIOClient
    
    @Published public var components: [String: Any] = [:]
    @Published public var connected = false
    
    public init(url: URL) {
        self.manager = SocketManager(socketURL: url, config: [.log(true)])
        self.socket = manager.defaultSocket
        
        setupSocketHandlers()
    }
    
    private func setupSocketHandlers() {
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.connected = true
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.connected = false
            }
        }
        
        socket.on("component") { [weak self] data, ack in
            guard let componentData = data[0] as? [String: Any],
                  let name = componentData["name"] as? String,
                  let component = componentData["component"] else { return }
            
            DispatchQueue.main.async {
                self?.components[name] = component
            }
        }
    }
    
    public func connect() {
        socket.connect()
    }
    
    public func disconnect() {
        socket.disconnect()
    }
    
    public func requestComponent(_ name: String) {
        socket.emit("requestComponent", name)
    }
}

// SwiftUI View Extensions
extension View {
    func mcpComponent(_ name: String, props: [String: Any]) -> some View {
        // TODO: Implement component rendering based on MCP data
        self
    }
}