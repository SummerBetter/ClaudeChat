import SwiftUI

struct SessionListView: View {
    @ObservedObject var store: SessionStore
    @Binding var showSettings: Bool
    @State private var editingSessionId: UUID?
    @State private var editingName: String = ""

    var body: some View {
        List(selection: $store.selectedSessionId) {
            ForEach(store.sessions) { session in
                if editingSessionId == session.id {
                    TextField("", text: $editingName)
                        .textFieldStyle(.plain)
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .help("用户设置")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: { store.showNewSessionSheet = true }) {
                    Label("新建会话", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .padding(10)
                Spacer()
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.name)
                .font(.body)
                .lineLimit(1)
            Text(session.workingDirectory)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(session.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func startRenaming(_ session: Session) {
        editingName = session.name
        editingSessionId = session.id
    }

    private func commitRename(_ session: Session) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.renameSession(session.id, to: trimmed)
        }
        editingSessionId = nil
    }
}