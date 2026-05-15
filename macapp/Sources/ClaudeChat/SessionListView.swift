import SwiftUI

struct SessionListView: View {
    @ObservedObject var store: SessionStore
    @Binding var showSettings: Bool
    var tunnelURL: String?
    var tunnelRunning: Bool
    var tunnelConnecting: Bool
    var tunnelError: String?
    var onToggleTunnel: () -> Void
    @State private var editingSessionId: UUID?
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selectedSessionId) {
                ForEach(store.sessions) { session in
                    if editingSessionId == session.id {
                        TextField("", text: $editingName).textFieldStyle(.plain)
                            .onSubmit { commitRename(session) }
                            .onExitCommand { editingSessionId = nil }
                    } else {
                        sessionRow(session)
                            .contextMenu {
                                Button("重命名") { startRenaming(session) }
                                Divider()
                                Button("删除", role: .destructive) { store.deleteSession(session.id) }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("会话")

            // Remote access panel
            Divider()
            remotePanel
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }.help("设置")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: { store.showNewSessionSheet = true }) {
                Label("新建会话", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private var remotePanel: some View {
        VStack(spacing: 8) {
            HStack {
                Circle().fill(tunnelRunning ? Color.green : (tunnelConnecting ? Color.yellow : Color.gray))
                    .frame(width: 8, height: 8)
                Text(tunnelConnecting ? "连接中..." : (tunnelRunning ? "远程已连接" : "远程已断开"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(tunnelRunning ? "关闭" : "启动") {
                    onToggleTunnel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(tunnelConnecting)
            }

            if let url = tunnelURL {
                HStack {
                    Text(url).font(.system(size: 9)).foregroundColor(.blue).lineLimit(1).truncationMode(.middle)
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    }
                    .buttonStyle(.borderless).controlSize(.mini)
                }
            }

            if let err = tunnelError {
                Text(err).font(.system(size: 9)).foregroundColor(.red).lineLimit(2)
            }
        }
        .padding(10)
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.name).font(.body).lineLimit(1)
            Text(session.workingDirectory).font(.caption).foregroundColor(.secondary).lineLimit(1)
            Text(formatDate(session.lastMessageAt)).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func startRenaming(_ session: Session) {
        editingName = session.name
        editingSessionId = session.id
    }

    private func commitRename(_ session: Session) {
        if !editingName.trimmingCharacters(in: .whitespaces).isEmpty {
            store.renameSession(session.id, to: editingName.trimmingCharacters(in: .whitespaces))
        }
        editingSessionId = nil
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 HH:mm"
        return fmt.string(from: date)
    }
}