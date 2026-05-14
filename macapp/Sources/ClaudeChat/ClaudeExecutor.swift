import Foundation

actor ClaudeExecutor {
    private var process: Process?
    private var sessionId: String?

    private static func findClaudePath() -> String? {
        let nvmDir = ProcessInfo.processInfo.environment["NVM_DIR"] ?? NSHomeDirectory() + "/.nvm"
        let versionsDir = nvmDir + "/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: versionsDir) {
            for v in versions.sorted(by: >) {
                let path = versionsDir + "/" + v + "/bin/claude"
                if FileManager.default.isExecutableFile(atPath: path) { return path }
            }
        }
        return nil
    }

    func setSessionId(_ sid: String?) {
        sessionId = sid
    }

    func run(
        prompt: String,
        workingDirectory: URL? = nil,
        permissionMode: PermMode = .acceptEdits,
        onEvent: @escaping @Sendable (MessageContent) -> Void,
        onSessionId: @escaping @Sendable (String) -> Void
    ) async throws {
        try Task.checkCancellation()

        guard let claudePath = Self.findClaudePath() else {
            throw ClaudeError.claudeNotFound
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: claudePath)
        var args = ["-p", prompt, "--output-format", "stream-json",
                    "--permission-mode", permissionMode.cliFlag, "--verbose"]
        if let sid = sessionId { args.append(contentsOf: ["--resume", sid]) }
        if let wd = workingDirectory {
            args.append(contentsOf: ["--add-dir", wd.path])
        }
        process.arguments = args
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = Pipe()
        process.environment = ProcessInfo.processInfo.environment
        if let wd = workingDirectory {
            process.currentDirectoryURL = wd
        }

        self.process = process
        try process.run()

        let stdoutHandle = stdoutPipe.fileHandleForReading

        for try await line in stdoutHandle.bytes.lines {
            guard !Task.isCancelled else { process.terminate(); break }
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            let type = dict["type"] as? String ?? ""

            if type == "system", dict["subtype"] as? String == "init",
               let sid = dict["session_id"] as? String {
                if sessionId == nil {
                    sessionId = sid
                    onSessionId(sid)
                }
            }

            if let message = dict["message"] as? [String: Any],
               let blocks = message["content"] as? [[String: Any]] {
                if type == "assistant" {
                    for block in blocks {
                        let bt = block["type"] as? String ?? ""
                        switch bt {
                        case "text":
                            if let text = block["text"] as? String { onEvent(.text(text)) }
                        case "tool_use":
                            if let name = block["name"] as? String,
                               let id = block["id"] as? String {
                                let inputStr = prettyJSON(block["input"]) ?? "{}"
                                onEvent(.toolUse(id: id, name: name, input: inputStr))
                            }
                        case "thinking":
                            if let text = block["thinking"] as? String { onEvent(.thinking(text)) }
                        default: break
                        }
                    }
                } else if type == "user" {
                    for block in blocks where block["type"] as? String == "tool_result" {
                        if let toolUseId = block["tool_use_id"] as? String {
                            let content: String
                            if let s = block["content"] as? String {
                                content = s
                            } else if let arr = block["content"] as? [[String: Any]] {
                                content = arr.compactMap { $0["text"] as? String }.joined()
                            } else {
                                content = ""
                            }
                            onEvent(.toolResult(
                                toolUseId: toolUseId,
                                content: content,
                                isError: block["is_error"] as? Bool ?? false
                            ))
                        }
                    }
                }
            }

            if type == "result", dict["is_error"] as? Bool == true {
                let msg = (dict["errors"] as? [String])?.joined(separator: "\n") ?? "Unknown error"
                throw ClaudeError.processExited(code: -1, stderr: msg)
            }
        }

        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let stderrData = try? stderrPipe.fileHandleForReading.readToEnd()
            let stderrMsg = stderrData
                .flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ClaudeError.processExited(code: process.terminationStatus, stderr: stderrMsg)
        }

        self.process = nil
    }

    func cancel() {
        process?.terminate()
        process = nil
    }

    private func prettyJSON(_ value: Any?) -> String? {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8)
        else {
            if let value { return "\(value)" }
            return nil
        }
        return str
    }
}

enum ClaudeError: Error, LocalizedError {
    case claudeNotFound
    case processExited(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .claudeNotFound: return "未找到 claude CLI"
        case let .processExited(code, stderr): return "claude 异常退出 (\(code)): \(stderr)"
        }
    }
}