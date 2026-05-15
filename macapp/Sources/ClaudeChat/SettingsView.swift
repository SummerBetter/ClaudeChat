import SwiftUI

struct SettingsView: View {
    @Binding var profile: UserProfile
    @ObservedObject var inviteManager: InviteCodeManager
    var tunnelURL: String?
    var tunnelRunning: Bool
    var tunnelConnecting: Bool
    var tunnelError: String?
    var onToggleTunnel: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let emojiOptions = ["👤", "🐱", "🐶", "🦊", "🐻", "🐼", "🐨", "🐯", "🐮", "🐸", "👻", "🤖", "👽", "🧑‍💻", "🦄", "🐉"]
    private let colorOptions = [
        ("蓝", "#007AFF"), ("青", "#5AC8FA"), ("绿", "#34C759"),
        ("橙", "#FF9500"), ("红", "#FF3B30"), ("紫", "#AF52DE"),
        ("粉", "#FF2D55"), ("灰", "#8E8E93")
    ]
    @State private var inviteLabel: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("设置").font(.headline)

                userSection
                Divider()
                claudeSection
                Divider()
                remoteSection
                Divider()
                inviteSection
                Divider()
                appSection

                Button("保存") {
                    profile.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .padding(.bottom, 8)
            }
            .padding(24)
        }
        .frame(width: 440, height: 600)
    }

    // MARK: - User section
    private var userSection: some View {
        VStack(spacing: 12) {
            Text("我的设置").font(.subheadline.weight(.medium))

            Text(profile.avatarEmoji).font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(Circle().fill(profile.color.opacity(0.2)))

            TextField("昵称", text: $profile.nickname)
                .textFieldStyle(.roundedBorder).frame(width: 200)

            emojiPicker(selection: $profile.avatarEmoji)
            colorPicker(selection: $profile.avatarColor)
        }
    }

    // MARK: - Claude section
    private var claudeSection: some View {
        VStack(spacing: 12) {
            Text("Claude 设置").font(.subheadline.weight(.medium))

            Group {
                if let d = profile.claudeAvatarImageData,
                   let nsImage = NSImage(data: d) {
                    Image(nsImage: nsImage).resizable().scaledToFill()
                        .frame(width: 56, height: 56).clipShape(Circle())
                } else {
                    Text(profile.claudeAvatarEmoji).font(.system(size: 36))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.orange.opacity(0.2)))
                }
            }

            TextField("昵称", text: $profile.claudeNickname)
                .textFieldStyle(.roundedBorder).frame(width: 200)

            emojiPicker(selection: $profile.claudeAvatarEmoji)

            HStack(spacing: 8) {
                Button("上传图片头像") { selectImage() }.buttonStyle(.bordered).controlSize(.small)
                if profile.claudeAvatarImageData != nil {
                    Button("清除") { profile.claudeAvatarImageData = nil }
                        .buttonStyle(.borderless).foregroundColor(.secondary).controlSize(.small)
                }
            }
        }
    }

    // MARK: - Remote access
    private var remoteSection: some View {
        VStack(spacing: 12) {
            Text("远程访问").font(.subheadline.weight(.medium))

            HStack {
                Circle()
                    .fill(tunnelRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(tunnelRunning ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(tunnelRunning ? "🛑 关闭远程访问" : "🔗 启动远程访问") {
                onToggleTunnel()
            }
            .buttonStyle(.borderedProminent)

            if let url = tunnelURL {
                HStack {
                    Text(url).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    }
                    .buttonStyle(.borderless).controlSize(.small)
                }
            }
        }
    }

    // MARK: - Invite codes
    private var inviteSection: some View {
        VStack(spacing: 12) {
            Text("邀请码管理").font(.subheadline.weight(.medium))

            // Generate
            HStack {
                TextField("备注（如：我的手机）", text: $inviteLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("生成邀请码") {
                    let code = inviteManager.generateCode(
                        label: inviteLabel.isEmpty ? "未命名" : inviteLabel
                    )
                    inviteLabel = ""
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(inviteManager.codes.count >= 10)
            }

            // List
            if inviteManager.codes.isEmpty {
                Text("暂无邀请码").font(.caption).foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(inviteManager.codes) { code in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(code.label).font(.caption.weight(.medium))
                                Text("使用: \(code.useCount) 次 · 过期: \(formatExpiry(code.expiresAt))")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("删除", role: .destructive) {
                                inviteManager.revoke(code.id)
                            }
                            .buttonStyle(.borderless).controlSize(.small)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
            }
        }
    }

    // MARK: - App section
    private var appSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("外观").font(.subheadline.weight(.medium))
            Picker("", selection: $profile.colorSchemeMode) {
                ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented).frame(width: 280)
        }
    }

    // MARK: - Shared
    private func emojiPicker(selection: Binding<String>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
            ForEach(emojiOptions, id: \.self) { emoji in
                Text(emoji).font(.title3).frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection.wrappedValue == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .onTapGesture { selection.wrappedValue = emoji }
            }
        }.frame(width: 260)
    }

    private func colorPicker(selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(colorOptions, id: \.1) { _, hex in
                Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(
                            selection.wrappedValue == hex ? Color.primary : Color.clear,
                            lineWidth: 2
                        )
                    )
                    .onTapGesture { selection.wrappedValue = hex }
            }
        }
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .webP, .gif, .bmp, .tiff]
        panel.allowsMultipleSelection = false
        panel.message = "选择 Claude 头像图片"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        let maxSize = 500_000
        if data.count > maxSize, let img = NSImage(contentsOf: url),
           let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
            profile.claudeAvatarImageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) ?? data
        } else {
            profile.claudeAvatarImageData = data
        }
    }

    private func formatExpiry(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }
}