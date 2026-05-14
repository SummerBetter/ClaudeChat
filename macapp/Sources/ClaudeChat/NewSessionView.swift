import SwiftUI

struct NewSessionView: View {
    @ObservedObject var store: SessionStore
    @State private var name: String = ""
    @State private var workingDirectory: String = NSHomeDirectory()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "plus.bubble")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text("新建会话")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("会话名称").font(.caption).foregroundColor(.secondary)
                TextField("输入会话名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("工作目录").font(.caption).foregroundColor(.secondary)
                HStack {
                    Text(workingDirectory)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("选择…") { chooseDirectory() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            }

            Text("claude 将在该目录下执行命令，可读取和修改该目录中的文件。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("取消") {
                    store.showNewSessionSheet = false
                }
                Spacer()
                Button("创建") {
                    let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? URL(fileURLWithPath: workingDirectory).lastPathComponent
                        : name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.createSession(name: finalName, workingDirectory: workingDirectory)
                    store.showNewSessionSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            name = URL(fileURLWithPath: workingDirectory).lastPathComponent
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "选择 claude 命令的工作目录"
        if panel.runModal() == .OK {
            workingDirectory = panel.url?.path ?? workingDirectory
        }
    }
}