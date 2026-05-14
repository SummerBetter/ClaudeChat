import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var profile: UserProfileStore
    @State private var input = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            permBar
            inputBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { isFocused = true }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { msg in
                        bubble(for: msg)
                            .id(msg.id)
                    }

                    if let err = viewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(err)
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages.last?.text ?? "") { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    @ViewBuilder
    private func bubble(for msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                avatarView(isUser: false)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isUser {
                        Text(profile.profile.nickname)
                            .font(.caption.weight(.medium))
                            .foregroundColor(profile.profile.color)
                    } else {
                        Text("Claude")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.orange)
                    }
                    Text(msg.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if msg.contents.isEmpty && viewModel.isRunning && !isUser {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text("思考中…").foregroundColor(.secondary)
                    }
                } else {
                    messageContent(msg)
                }

                if !msg.contents.isEmpty && viewModel.isRunning
                    && !isUser && msg.id == viewModel.messages.last?.id {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text("思考中…").foregroundColor(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isUser
                          ? profile.profile.color.opacity(0.12)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isUser
                            ? profile.profile.color.opacity(0.2)
                            : Color.secondary.opacity(0.15),
                            lineWidth: 1)
            )

            if isUser {
                avatarView(isUser: true)
            }

            if !isUser { Spacer(minLength: 50) }
        }
    }

    private func avatarView(isUser: Bool) -> some View {
        Text(isUser ? profile.profile.avatarEmoji : "✨")
            .font(.title3)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(isUser
                          ? profile.profile.color.opacity(0.15)
                          : Color.orange.opacity(0.15))
            )
    }

    @ViewBuilder
    private func messageContent(_ msg: ChatMessage) -> some View {
        ForEach(Array(msg.contents.enumerated()), id: \.offset) { _, content in
            switch content {
            case .text(let text):
                MarkdownBlockView(blocks: MarkdownParser.parse(text))

            case .image(let data, _):
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("[图片]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            case .thinking(let text):
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.caption2)
                    Text(text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))

            case .toolUse(_, let name, let input):
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.blue)
                        Text(formattedToolInput(name: name, input: input))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.08)))

            case .toolResult(_, let contentText, let isError):
                HStack(spacing: 4) {
                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(isError ? .red : .green)
                    Text(contentText)
                        .font(.caption)
                        .foregroundColor(isError ? .red : .green)
                        .lineLimit(2)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isError ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
                )
            }
        }
    }

    private func formattedToolInput(name: String, input: String) -> String {
        guard let data = input.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return input }
        let keyOrder = ["file_path", "command", "pattern", "path", "content"]
        for key in keyOrder {
            if let value = dict[key] as? String {
                return value.count > 60 ? String(value.prefix(60)) + "…" : value
            }
        }
        return input
    }

    // MARK: - Permission bar

    private var permBar: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("权限:")
                .font(.caption2)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: { viewModel.permissionMode },
                set: { viewModel.setPermissionMode($0) }
            )) {
                ForEach(PermMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入消息…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .onSubmit { submit() }

            if viewModel.isRunning {
                Button(action: { viewModel.cancel() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Button(action: { submit() }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !viewModel.isRunning else { return }
        viewModel.send(trimmed)
        input = ""
    }
}