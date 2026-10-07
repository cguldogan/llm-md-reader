import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView(columnVisibility: $model.sidebarVisibility) {
            FileTreeView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 420)
        } detail: {
            ReaderView()
        }
        .frame(minWidth: 760, minHeight: 480)
        .preferredColorScheme(model.appearance.colorScheme)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            model.refreshFolder()
        }
    }
}
