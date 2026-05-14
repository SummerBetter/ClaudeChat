import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var selectedSessionId: UUID?
    @Published var currentViewModel: ChatViewModel?
    @Published var showNewSessionSheet = false

    private var viewModelCache: [UUID: ChatViewModel] = [:]

    private var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClaudeChat")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }

    init() {
        loadSessions()
        if let first = sessions.first?.id {
            selectSession(first)
        }
    }

    // MARK: - Session CRUD

    func createSession(name: String, workingDirectory: String) {
        let session = Session(
            name: name,
            workingDirectory: workingDirectory
        )
        sessions.append(session)
        saveSessions()
        selectSession(session.id)
    }

    func deleteSession(_ id: UUID) {
        viewModelCache[id]?.cancel()
        viewModelCache[id] = nil
        sessions.removeAll { $0.id == id }
        saveSessions()
        if selectedSessionId == id {
            selectSession(sessions.first?.id)
        }
    }

    func renameSession(_ id: UUID, to newName: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].name = newName
        sessions[idx].updatedAt = Date()
        saveSessions()
    }

    // MARK: - Navigation

    func selectSession(_ id: UUID?) {
        if selectedSessionId != id {
            selectedSessionId = id
        }
        guard let id else {
            currentViewModel = nil
            return
        }

        if let cached = viewModelCache[id] {
            currentViewModel = cached
        } else if let session = sessions.first(where: { $0.id == id }) {
            let vm = ChatViewModel(
                sessionId: session.id,
                initialMessages: session.messages,
                workingDirectory: URL(fileURLWithPath: session.workingDirectory),
                permissionMode: session.permissionMode,
                initialClaudeSessionId: session.claudeSessionId,
                onMessagesChanged: { [weak self] messages in
                    self?.persistMessages(for: id, messages: messages)
                },
                onClaudeSessionIdChanged: { [weak self] sid in
                    self?.persistClaudeSessionId(for: id, sid: sid)
                },
                onPermissionModeChanged: { [weak self] mode in
                    self?.persistPermissionMode(for: id, mode: mode)
                }
            )
            viewModelCache[id] = vm
            currentViewModel = vm
        }
    }

    // MARK: - Persistence callbacks

    private func persistMessages(for id: UUID, messages: [ChatMessage]) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].messages = messages
        sessions[idx].updatedAt = Date()
        saveSessions()
    }

    private func persistClaudeSessionId(for id: UUID, sid: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].claudeSessionId = sid
        sessions[idx].updatedAt = Date()
        saveSessions()
    }

    private func persistPermissionMode(for id: UUID, mode: PermMode) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].permissionMode = mode
        sessions[idx].updatedAt = Date()
        saveSessions()
    }

    // MARK: - File I/O

    private func loadSessions() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Session].self, from: data)
        else { return }
        sessions = decoded
    }

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}