import SwiftUI

struct SettingsView: View {
    @Binding var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    private let emojiOptions = ["👤", "🐱", "🐶", "🦊", "🐻", "🐼", "🐨", "🐯", "🐮", "🐸", "👻", "🤖", "👽", "🧑‍💻", "🦄", "🐉"]
    private let colorOptions = [
        ("蓝", "#007AFF"), ("青", "#5AC8FA"), ("绿", "#34C759"),
        ("橙", "#FF9500"), ("红", "#FF3B30"), ("紫", "#AF52DE"),
        ("粉", "#FF2D55"), ("灰", "#8E8E93")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("用户设置")
                .font(.headline)

            // Avatar preview
            Text(profile.avatarEmoji)
                .font(.system(size: 48))
                .frame(width: 72, height: 72)
                .background(
                    Circle().fill(profile.color.opacity(0.2))
                )

            // Nickname
            VStack(alignment: .leading, spacing: 6) {
                Text("昵称").font(.caption).foregroundColor(.secondary)
                TextField("", text: $profile.nickname)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            // Emoji picker
            VStack(alignment: .leading, spacing: 6) {
                Text("头像").font(.caption).foregroundColor(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Text(emoji)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(profile.avatarEmoji == emoji ? profile.color.opacity(0.2) : Color.clear)
                            )
                            .onTapGesture { profile.avatarEmoji = emoji }
                    }
                }
                .frame(width: 280)
            }

            // Color picker
            VStack(alignment: .leading, spacing: 6) {
                Text("颜色").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(colorOptions, id: \.1) { name, hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(
                                    profile.avatarColor == hex ? Color.primary : Color.clear,
                                    lineWidth: 2
                                )
                            )
                            .onTapGesture { profile.avatarColor = hex }
                    }
                }
            }

            // Color scheme mode
            VStack(alignment: .leading, spacing: 6) {
                Text("外观").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $profile.colorSchemeMode) {
                    ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            Button("保存") {
                profile.save()
                dismiss()
            }
            .keyboardShortcut(.return)
        }
        .padding()
        .frame(width: 360)
    }
}