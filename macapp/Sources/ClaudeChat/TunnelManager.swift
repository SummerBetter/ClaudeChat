import Foundation

final class TunnelManager {
    private var process: Process?
    private(set) var publicURL: String?
    private let port: Int

    init(port: Int = 8888) { self.port = port }
    var isRunning: Bool { process?.isRunning == true }

    func start(onURL: @escaping (String) -> Void, onError: @escaping (Error) -> Void) {
        let logPath = NSTemporaryDirectory() + "cloudflared-\(UUID().uuidString).log"

        DispatchQueue.global().async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [
                "-c",
                "/opt/homebrew/bin/cloudflared tunnel --url http://localhost:\(self?.port ?? 8888) --no-autoupdate > \(logPath) 2>&1"
            ]
            self?.process = process

            do { try process.run() } catch { onError(error); return }

            // Poll log file for URL
            let deadline = Date().addingTimeInterval(25)
            while Date() < deadline {
                Thread.sleep(forTimeInterval: 0.5)
                guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else { continue }
                if let range = content.range(of: #"https://[^\s]*\.trycloudflare\.com"#,
                                             options: .regularExpression) {
                    let url = String(content[range])
                    self?.publicURL = url
                    DispatchQueue.main.async { onURL(url) }
                    return
                }
            }

            process.terminate()
            try? FileManager.default.removeItem(atPath: logPath)
            DispatchQueue.main.async { onError(TunnelError.timeout("启动超时")) }
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        publicURL = nil
    }
}

enum TunnelError: Error, LocalizedError {
    case cloudflaredNotFound
    case timeout(String)
    var errorDescription: String? {
        switch self {
        case .cloudflaredNotFound: return "cloudflared 未安装"
        case .timeout(let msg): return msg
        }
    }
}