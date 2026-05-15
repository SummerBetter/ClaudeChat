import Foundation
import Network

/// HTTP server using Network.framework. Zero external dependencies.
final class HTTPServer {
    let port: UInt16
    private var listener: NWListener?
    private(set) var isRunning = false

    typealias GetSessions = () -> [Session]
    typealias GetMessages = (UUID) -> [ChatMessage]?
    typealias SendMessage = (UUID, String) -> Void
    typealias IsRunning = (UUID) -> Bool
    private var getSessionsBlock: GetSessions?
    private var getMessagesBlock: GetMessages?
    private var sendMessageBlock: SendMessage?
    private var isAssistantRunning: IsRunning?
    private var activeStreams: [UUID: StreamState] = [:]

    struct StreamState {
        var contents: [ContentJSON] = []
        var isComplete = false
    }

    struct ContentJSON: Codable {
        var type: String
        var text: String?
        var name: String?
        var input: String?
        var content: String?
        var isError: Bool?
    }

    func configure(getSessions: @escaping GetSessions,
                   getMessages: @escaping GetMessages,
                   sendMessage: @escaping SendMessage,
                   isRunning: @escaping IsRunning) {
        getSessionsBlock = getSessions
        getMessagesBlock = getMessages
        sendMessageBlock = sendMessage
        isAssistantRunning = isRunning
    }

    init(port: UInt16 = 8888) { self.port = port }

    func start() -> String? {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try? NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
        guard let listener else { return "无法创建监听器" }

        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())
            self?.receive(on: conn)
        }

        listener.stateUpdateHandler = { state in
            if case .failed(let err) = state {
                print("[HTTPServer] Error: \(err)")
            }
        }

        listener.start(queue: .global())
        self.listener = listener
        self.isRunning = true
        return nil
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Receive data

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else { conn.cancel(); return }
            self.handleRequest(data: data, conn: conn)
        }
    }

    private func handleRequest(data: Data, conn: NWConnection) {
        guard let requestStr = String(data: data, encoding: .utf8) else { conn.cancel(); return }
        let lines = requestStr.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { conn.cancel(); return }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { conn.cancel(); return }
        let method = parts[0]
        let path = parts[1]

        var body: String?
        if let blank = lines.firstIndex(of: ""), blank + 1 < lines.count {
            body = lines[(blank + 1)...].joined(separator: "\r\n")
        }

        // Auth
        if path.hasPrefix("/api/") && path != "/api/login" {
            guard let authLine = lines.first(where: { $0.lowercased().hasPrefix("authorization:") }),
                  let token = authLine.components(separatedBy: "Bearer ").last?.trimmingCharacters(in: .whitespaces),
                  JWTManager.verify(token) != nil
            else {
                respond(conn: conn, status: 401, body: #"{"error":"Unauthorized"}"#)
                return
            }
        }

        // Route on main actor for data access
        Task { @MainActor in
            let (ct, body) = self.route(method: method, path: path, body: body)
            self.respond(conn: conn, status: 200, contentType: ct, body: body)
        }
    }

    // MARK: - Routing

    private func route(method: String, path: String, body: String?) -> (String, String) {
        switch (method, path) {
        case ("POST", "/api/login"): return login(body)
        case ("GET", "/api/sessions"): return listSessions()
        case ("GET", _) where path.hasPrefix("/api/sessions/") && path.hasSuffix("/messages"):
            let sid = extract(path, prefix: "/api/sessions/", suffix: "/messages")
            return getMessages(sid)
        case ("POST", _) where path.hasPrefix("/api/sessions/") && path.hasSuffix("/send"):
            let sid = extract(path, prefix: "/api/sessions/", suffix: "/send")
            return sendMsg(sid, body)
        case ("GET", _) where path.hasPrefix("/api/stream/"):
            let sid = path.replacingOccurrences(of: "/api/stream/", with: "")
            return stream(sid)
        case ("GET", "/"):
            return webUI()
        default:
            return ("text/html", "Not Found")
        }
    }

    // MARK: - Respond

    private func respond(conn: NWConnection, status: Int, contentType: String = "application/json", body: String) {
        let statusText = status == 200 ? "OK" : (status == 401 ? "Unauthorized" : "Error")
        let resp = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: - API handlers

    private func login(_ body: String?) -> (String, String) {
        guard let body, let d = body.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: String],
              let code = j["code"]
        else { return ("application/json", #"{"error":"need code"}"#) }
        guard InviteCodeManager.shared.verify(code) else {
            return ("application/json", #"{"error":"invalid code"}"#)
        }
        let now = Int(Date().timeIntervalSince1970)
        let p = JWTPayload(sub: "user", iat: now, exp: now + 86400)
        guard let tok = JWTManager.sign(payload: p) else {
            return ("application/json", #"{"error":"jwt fail"}"#)
        }
        return ("application/json", #"{"token":"\#(tok)","expiresIn":86400}"#)
    }

    private func listSessions() -> (String, String) {
        let ss = getSessionsBlock?() ?? []
        let list = ss.map { s in #"{"id":"\#(s.id.uuidString)","name":"\#(esc(s.name))","workingDirectory":"\#(esc(s.workingDirectory))","lastMessageAt":\#(Int(s.lastMessageAt.timeIntervalSince1970)),"messageCount":\#(s.messages.count)}"# }
        return ("application/json", "[\(list.joined(separator: ","))]")
    }

    private func getMessages(_ sid: String) -> (String, String) {
        guard let id = UUID(uuidString: sid), let msgs = getMessagesBlock?(id)
        else { return ("application/json", "[]") }
        let arr = msgs.map { m in
            let cts = m.contents.map { c in
                switch c {
                case .text(let t): return #"{"type":"text","text":"\#(esc(t))"}"#
                case .image: return #"{"type":"image"}"#
                case .thinking(let t): return #"{"type":"thinking","text":"\#(esc(t))"}"#
                case .toolUse(_, let n, let i): return #"{"type":"tool_use","name":"\#(esc(n))","input":"\#(esc(i))"}"#
                case .toolResult(_, let ct, let e): return #"{"type":"tool_result","content":"\#(esc(ct))","isError":\#(e)}"#
                }
            }
            return #"{"id":"\#(m.id.uuidString)","role":"\#(m.role.rawValue)","contents":[\#(cts.joined(separator: ","))],"timestamp":\#(Int(m.timestamp.timeIntervalSince1970))}"#
        }
        return ("application/json", "[\(arr.joined(separator: ","))]")
    }

    private func sendMsg(_ sid: String, _ body: String?) -> (String, String) {
        guard let id = UUID(uuidString: sid), let body, let d = body.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: String],
              let msg = j["message"]?.trimmingCharacters(in: .whitespaces), !msg.isEmpty
        else { return ("application/json", #"{"error":"invalid"}"#) }
        sendMessageBlock?(id, msg)
        let streamId = UUID()
        activeStreams[streamId] = StreamState()
        // Background poll — fast refresh (~0.8s) + structured content
        Task { @MainActor [weak self] in
            guard let self else { return }
            while true {
                try? await Task.sleep(for: .milliseconds(800))
                guard self.activeStreams.keys.contains(streamId) else { break }
                let ss = self.getSessionsBlock?() ?? []
                let last = ss.first(where: { $0.id == id })?.messages.last
                guard last?.role == .assistant, let lastMsg = last else { continue }
                let isDone = self.isAssistantRunning?(id) == false

                var state = StreamState()
                state.contents = lastMsg.contents.map { c in
                    switch c {
                    case .text(let t): return ContentJSON(type: "text", text: t)
                    case .thinking(let t): return ContentJSON(type: "thinking", text: t)
                    case .toolUse(_, let n, let i): return ContentJSON(type: "tool_use", name: n, input: i)
                    case .toolResult(_, let ct, let e): return ContentJSON(type: "tool_result", content: ct, isError: e)
                    case .image: return ContentJSON(type: "image")
                    }
                }
                state.isComplete = isDone
                self.activeStreams[streamId] = state
                if isDone { break }
            }
        }
        return ("application/json", #"{"streamId":"\#(streamId.uuidString)"}"#)
    }

    private func stream(_ sid: String) -> (String, String) {
        guard let id = UUID(uuidString: sid) else { return ("application/json", #"{"contents":[],"isComplete":true}"#) }
        let s = activeStreams[id] ?? StreamState(isComplete: true)
        let contentsJSON = s.contents.map { c -> String in
            var parts: [String] = [#""type":"\#(c.type)""#]
            if let t = c.text { parts.append(#""text":"\#(esc(t))""#) }
            if let n = c.name { parts.append(#""name":"\#(esc(n))""#) }
            if let i = c.input { parts.append(#""input":"\#(esc(i))""#) }
            if let ct = c.content { parts.append(#""content":"\#(esc(ct))""#) }
            if let e = c.isError { parts.append(#""isError":\#(e)"#) }
            return "{\(parts.joined(separator: ","))}"
        }
        return ("application/json", #"{"contents":[\#(contentsJSON.joined(separator: ","))],"isComplete":\#(s.isComplete)}"#)
    }

    private func webUI() -> (String, String) {
        // When run as .app bundle, resources are in Contents/Resources/
        // When run directly, they're in the .build directory
        var paths: [String] = []
        if let resourcePath = Bundle.main.resourcePath {
            paths.append(resourcePath + "/index.html")
        }
        if let execPath = Bundle.main.executablePath {
            let appRoot = (execPath as NSString).deletingLastPathComponent + "/../Resources/index.html"
            paths.append(appRoot)
        }
        paths.append(FileManager.default.currentDirectoryPath + "/.build/debug/ClaudeChat_ClaudeChat.bundle/Resources/index.html")
        paths.append(FileManager.default.currentDirectoryPath + "/Sources/ClaudeChat/Resources/index.html")

        for path in paths {
            if FileManager.default.fileExists(atPath: path),
               let html = try? String(contentsOfFile: path, encoding: .utf8) {
                return ("text/html", html)
            }
        }
        return ("text/html", "<!doctype html><html><body><h1>ClaudeChat</h1><p>Web UI not found. Paths: \(paths.joined(separator: ", "))</p></body></html>")
    }

    private func extract(_ path: String, prefix: String, suffix: String) -> String {
        path.replacingOccurrences(of: prefix, with: "").replacingOccurrences(of: suffix, with: "")
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "")
    }
}