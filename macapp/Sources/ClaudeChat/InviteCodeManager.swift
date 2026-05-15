import Foundation
import CryptoKit

struct InviteCode: Identifiable, Equatable, Codable {
    let id: UUID
    let codeHash: String
    let label: String
    let createdAt: Date
    let expiresAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    var isExpired: Bool { Date() > expiresAt }

    init(code: String, label: String, ttlDays: Int = 7) {
        self.id = UUID()
        self.codeHash = Self.sha256(code)
        self.label = label
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(Double(ttlDays) * 86400)
        self.useCount = 0
    }

    func verify(_ code: String) -> Bool {
        !isExpired && Self.sha256(code) == codeHash
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Thread-safe invite code manager. ObservableObject for SwiftUI binding.
final class InviteCodeManager: ObservableObject, @unchecked Sendable {
    static let shared = InviteCodeManager()

    private let storageKey = "InviteCodes"
    private let lock = NSLock()
    @Published private var _codes: [InviteCode] = []

    var codes: [InviteCode] {
        lock.lock(); defer { lock.unlock() }
        return _codes
    }

    init() { load() }

    func generateCode(label: String, ttlDays: Int = 7) -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
        let raw = String((0..<8).map { _ in chars.randomElement()! })
        let code = InviteCode(code: raw, label: label, ttlDays: ttlDays)
        var snapshot: [InviteCode]
        lock.lock()
        _codes.append(code)
        snapshot = _codes
        lock.unlock()
        save(snapshot)
        return raw
    }

    func verify(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }
        lock.lock()
        var found = false
        for i in _codes.indices {
            if _codes[i].verify(input) {
                _codes[i].lastUsedAt = Date()
                _codes[i].useCount += 1
                found = true
                break
            }
        }
        let snapshot = _codes
        lock.unlock()
        if found { save(snapshot) }
        return found
    }

    func revoke(_ id: UUID) {
        lock.lock()
        _codes.removeAll { $0.id == id }
        let snapshot = _codes
        lock.unlock()
        save(snapshot)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([InviteCode].self, from: data)
        else { return }
        lock.lock()
        _codes = decoded.filter { !$0.isExpired }
        lock.unlock()
    }

    private func save(_ codes: [InviteCode]) {
        guard let data = try? JSONEncoder().encode(codes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}