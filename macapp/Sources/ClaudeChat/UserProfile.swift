import SwiftUI

@MainActor
final class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile

    init() {
        self.profile = UserProfile.load()
    }

    func save() {
        profile.save()
    }
}

enum ColorSchemeMode: String, CaseIterable, Codable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct UserProfile: Equatable, Codable {
    var nickname: String
    var avatarEmoji: String
    var avatarColor: String
    var claudeNickname: String
    var claudeAvatarEmoji: String
    var claudeAvatarImageData: Data?
    var colorSchemeMode: ColorSchemeMode

    static let `default` = UserProfile(
        nickname: "你",
        avatarEmoji: "👤",
        avatarColor: "#007AFF",
        claudeNickname: "Claude",
        claudeAvatarEmoji: "✨",
        claudeAvatarImageData: nil,
        colorSchemeMode: .system
    )

    var color: Color {
        Color(hex: avatarColor)
    }

    private enum CodingKeys: String, CodingKey {
        case nickname, avatarEmoji, avatarColor, claudeNickname, claudeAvatarEmoji, claudeAvatarImageData, colorSchemeMode
    }

    init(nickname: String, avatarEmoji: String, avatarColor: String,
         claudeNickname: String, claudeAvatarEmoji: String,
         claudeAvatarImageData: Data? = nil,
         colorSchemeMode: ColorSchemeMode) {
        self.nickname = nickname
        self.avatarEmoji = avatarEmoji
        self.avatarColor = avatarColor
        self.claudeNickname = claudeNickname
        self.claudeAvatarEmoji = claudeAvatarEmoji
        self.claudeAvatarImageData = claudeAvatarImageData
        self.colorSchemeMode = colorSchemeMode
    }

    private static let defaultsKey = "UserProfile"

    static func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return .default }
        return profile
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    // Custom decoding for backward compatibility with old data missing colorSchemeMode
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nickname = (try? c.decode(String.self, forKey: .nickname)) ?? Self.default.nickname
        avatarEmoji = (try? c.decode(String.self, forKey: .avatarEmoji)) ?? Self.default.avatarEmoji
        avatarColor = (try? c.decode(String.self, forKey: .avatarColor)) ?? Self.default.avatarColor
        claudeNickname = (try? c.decode(String.self, forKey: .claudeNickname)) ?? Self.default.claudeNickname
        claudeAvatarEmoji = (try? c.decode(String.self, forKey: .claudeAvatarEmoji)) ?? Self.default.claudeAvatarEmoji
        claudeAvatarImageData = try? c.decode(Data.self, forKey: .claudeAvatarImageData)
        colorSchemeMode = (try? c.decode(ColorSchemeMode.self, forKey: .colorSchemeMode)) ?? .system
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 122.0 / 255; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}