import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var permissionMode: PermMode

    private let executor = ClaudeExecutor()
    private var assistantMessageIndex: Int?
    private let workingDirectory: URL?
    private let onMessagesChanged: ([ChatMessage]) -> Void
    private let onClaudeSessionIdChanged: (String) -> Void
    private let onPermissionModeChanged: (PermMode) -> Void

    init(
        sessionId: UUID,
        initialMessages: [ChatMessage],
        workingDirectory: URL?,
        permissionMode: PermMode,
        initialClaudeSessionId: String?,
        onMessagesChanged: @escaping ([ChatMessage]) -> Void,
        onClaudeSessionIdChanged: @escaping (String) -> Void,
        onPermissionModeChanged: @escaping (PermMode) -> Void
    ) {
        self.workingDirectory = workingDirectory
        self.permissionMode = permissionMode
        self.onMessagesChanged = onMessagesChanged
        self.onClaudeSessionIdChanged = onClaudeSessionIdChanged
        self.onPermissionModeChanged = onPermissionModeChanged
        self.messages = initialMessages

        if let sid = initialClaudeSessionId {
            Task { await executor.setSessionId(sid) }
        }
    }

    func send(_ prompt: String, images: [(data: Data, mediaType: String)] = []) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty else { return }
        guard !isRunning else { return }

        // Build user message
        var userContents: [MessageContent] = []
        for img in images {
            userContents.append(.image(data: img.data, mediaType: img.mediaType))
        }
        if !trimmed.isEmpty {
            userContents.append(.text(trimmed))
        }
        messages.append(ChatMessage(role: .user, contents: userContents))

        let idx = messages.count
        messages.append(ChatMessage(role: .assistant, contents: []))
        assistantMessageIndex = idx
        isRunning = true
        errorMessage = nil
        onMessagesChanged(messages)

        let mode = permissionMode
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.executor.run(
                    prompt: trimmed,
                    workingDirectory: self.workingDirectory,
                    permissionMode: mode,
                    onEvent: { [weak self] content in
                        Task { @MainActor [weak self] in
                            guard let self,
                                  let idx = self.assistantMessageIndex,
                                  self.messages.indices.contains(idx) else { return }
                            self.messages[idx].contents.append(content)
                            self.onMessagesChanged(self.messages)
                        }
                    },
                    onSessionId: { [weak self] sid in
                        Task { @MainActor [weak self] in
                            self?.onClaudeSessionIdChanged(sid)
                        }
                    }
                )
            } catch {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
            }
            Task { @MainActor in self.isRunning = false }
        }
    }

    func setPermissionMode(_ mode: PermMode) {
        permissionMode = mode
        onPermissionModeChanged(mode)
    }

    func cancel() {
        Task { await executor.cancel() }
        isRunning = false
    }
}