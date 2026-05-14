import Foundation

enum MessageContent {
    case text(String)
    case image(data: Data, mediaType: String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case thinking(String)

    var plainText: String {
        switch self {
        case .text(let t): return t
        case .image: return "[图片]"
        case .thinking(let t): return t
        case .toolUse(_, let name, let input):
            return "[\(toolIcon(name)) \(name)] \(summary(input))"
        case .toolResult(_, let content, let isError):
            return isError ? "[x \(summary(content))]" : "[ok \(summary(content))]"
        }
    }

    private func toolIcon(_ name: String) -> String {
        switch name.lowercased() {
        case "write", "edit": return "WRITE"
        case "bash", "run": return "RUN"
        case "grep", "search": return "GREP"
        case "read": return "READ"
        case "askuserquestion": return "ASK"
        case "task", "taskcreate": return "TASK"
        case "agent", "explore": return "AGENT"
        default: return "TOOL"
        }
    }

    private func summary(_ input: String, maxLen: Int = 80) -> String {
        if input.count <= maxLen { return input }
        return String(input.prefix(maxLen)) + "..."
    }
}

// MARK: - Codable

extension MessageContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, text, data, mediaType, id, name, input, toolUseId, content, isError
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "text":
            self = .text(try c.decode(String.self, forKey: .text))
        case "image":
            self = .image(
                data: try c.decode(Data.self, forKey: .data),
                mediaType: try c.decode(String.self, forKey: .mediaType)
            )
        case "tool_use":
            self = .toolUse(
                id: try c.decode(String.self, forKey: .id),
                name: try c.decode(String.self, forKey: .name),
                input: try c.decode(String.self, forKey: .input)
            )
        case "tool_result":
            self = .toolResult(
                toolUseId: try c.decode(String.self, forKey: .toolUseId),
                content: try c.decode(String.self, forKey: .content),
                isError: try c.decode(Bool.self, forKey: .isError)
            )
        case "thinking":
            self = .thinking(try c.decode(String.self, forKey: .text))
        default:
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try c.encode("text", forKey: .type)
            try c.encode(t, forKey: .text)
        case .image(let data, let mediaType):
            try c.encode("image", forKey: .type)
            try c.encode(data, forKey: .data)
            try c.encode(mediaType, forKey: .mediaType)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(input, forKey: .input)
        case .toolResult(let toolUseId, let content, let isError):
            try c.encode("tool_result", forKey: .type)
            try c.encode(toolUseId, forKey: .toolUseId)
            try c.encode(content, forKey: .content)
            try c.encode(isError, forKey: .isError)
        case .thinking(let t):
            try c.encode("thinking", forKey: .type)
            try c.encode(t, forKey: .text)
        }
    }
}

// MARK: - Equatable

extension MessageContent: Equatable {
    static func == (lhs: MessageContent, rhs: MessageContent) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.image(let da, let ma), .image(let db, let mb)): return da == db && ma == mb
        case (.toolUse(let ia, let na, let pa), .toolUse(let ib, let nb, let pb)):
            return ia == ib && na == nb && pa == pb
        case (.toolResult(let ta, let ca, let ea), .toolResult(let tb, let cb, let eb)):
            return ta == tb && ca == cb && ea == eb
        case (.thinking(let a), .thinking(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - PermMode

enum PermMode: String, CaseIterable, Codable {
    case acceptEdits
    case bypassPermissions

    var label: String {
        switch self {
        case .acceptEdits: return "仅工作目录"
        case .bypassPermissions: return "全部放行"
        }
    }

    var cliFlag: String { rawValue }
}

// MARK: - ChatMessage

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    var contents: [MessageContent]
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, contents: [MessageContent] = [], text: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        if let text {
            self.contents = [.text(text)]
        } else {
            self.contents = contents
        }
        self.timestamp = timestamp
    }

    var text: String {
        contents.map(\.plainText).joined()
    }

    enum Role: String, Codable, Equatable {
        case user, assistant
    }
}

// MARK: - Session

struct Session: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var workingDirectory: String
    var permissionMode: PermMode
    var claudeSessionId: String?
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        workingDirectory: String,
        permissionMode: PermMode = .acceptEdits,
        claudeSessionId: String? = nil,
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.permissionMode = permissionMode
        self.claudeSessionId = claudeSessionId
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}