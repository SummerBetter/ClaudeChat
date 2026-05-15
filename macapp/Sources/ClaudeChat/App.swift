import SwiftUI

@main
struct ClaudeChatApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var userProfile = UserProfileStore()
    @StateObject private var inviteManager = InviteCodeManager()
    @State private var showSettings = false
    @State private var tunnelURL: String?
    @State private var tunnelRunning = false
    @State private var tunnelConnecting = false
    @State private var tunnelError: String?

    private let httpServer = HTTPServer(port: 8888)
    private let tunnelManager = TunnelManager(port: 8888)

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SessionListView(
                    store: store,
                    showSettings: $showSettings,
                    tunnelURL: tunnelURL,
                    tunnelRunning: tunnelRunning,
                    tunnelConnecting: tunnelConnecting,
                    tunnelError: tunnelError,
                    onToggleTunnel: { toggleRemoteAccess() }
                )
                .navigationSplitViewColumnWidth(min: 190, ideal: 230)
            } detail: {
                if let vm = store.currentViewModel {
                    ChatView(viewModel: vm, profile: userProfile)
                } else {
                    emptyState
                }
            }
            .frame(minWidth: 680, minHeight: 520)
            .tint(userProfile.profile.color)
            .preferredColorScheme(userProfile.profile.colorSchemeMode.colorScheme)
            .onChange(of: store.selectedSessionId) { _, newId in store.selectSession(newId) }
            .sheet(isPresented: $store.showNewSessionSheet) { NewSessionView(store: store) }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    profile: Binding(get: { userProfile.profile }, set: { userProfile.profile = $0; userProfile.save() }),
                    inviteManager: inviteManager,
                    tunnelURL: tunnelURL,
                    tunnelRunning: tunnelRunning,
                    tunnelConnecting: tunnelConnecting,
                    tunnelError: tunnelError,
                    onToggleTunnel: { toggleRemoteAccess() }
                )
            }
            .onAppear {
                httpServer.configure(
                    getSessions: { store.sessions },
                    getMessages: { id in store.sessions.first(where: { $0.id == id })?.messages },
                    sendMessage: { id, msg in store.selectSession(id); store.currentViewModel?.send(msg) }
                )
                // Auto-start HTTP server
                if let err = httpServer.start() {
                    tunnelError = err
                } else {
                    print("[ClaudeChat] HTTP on port 8888 OK")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 48)).foregroundColor(.secondary)
            Text("没有会话").font(.title2)
            Text("从侧边栏新建一个会话开始对话").foregroundColor(.secondary)
            Button("新建会话") { store.showNewSessionSheet = true }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleRemoteAccess() {
        if tunnelRunning {
            tunnelManager.stop()
            tunnelRunning = false
            tunnelURL = nil
            tunnelError = nil
        } else {
            tunnelError = nil
            tunnelConnecting = true
            tunnelManager.start(
                onURL: { tunnelURL = $0; tunnelRunning = true; tunnelConnecting = false },
                onError: { tunnelError = $0.localizedDescription; tunnelConnecting = false }
            )
        }
    }
}