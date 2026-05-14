import SwiftUI

@main
struct ClaudeChatApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var userProfile = UserProfileStore()
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SessionListView(store: store, showSettings: $showSettings)
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
            .onChange(of: store.selectedSessionId) { _, newId in
                store.selectSession(newId)
            }
            .sheet(isPresented: $store.showNewSessionSheet) {
                NewSessionView(store: store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(profile: Binding(
                    get: { userProfile.profile },
                    set: { userProfile.profile = $0; userProfile.save() }
                ))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("没有会话")
                .font(.title2)
            Text("从侧边栏新建一个会话开始对话")
                .foregroundColor(.secondary)
            Button("新建会话") {
                store.showNewSessionSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}