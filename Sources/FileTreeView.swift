import SwiftUI

struct FileTreeView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: URL?

    var body: some View {
        Group {
            if model.folderURL != nil {
                sidebar
            } else {
                noFolderView
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button("Enclosing Folder", systemImage: "chevron.up", action: goUp)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
            .disabled(model.folderURL.map { $0.path == "/" } ?? true)
            .help("Enclosing Folder")

            Text(model.folderURL?.lastPathComponent ?? "")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button("Refresh", systemImage: "arrow.clockwise", action: model.refreshFolder)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var list: some View {
        List(selection: $selection) {
            OutlineGroup(model.sidebarItems, children: \.children) { node in
                HStack(spacing: 6) {
                    Image(systemName: node.isDirectory ? "folder" : "doc.text")
                        .foregroundStyle(.secondary)
                    Text(node.name)
                        .lineLimit(1)
                }
                .tag(node.id)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { _, url in
            handleSelection(url)
        }
        .onChange(of: model.fileURL) { _, url in
            selection = url
        }
    }

    private func goUp() {
        guard let folder = model.folderURL else { return }
        let parent = folder.deletingLastPathComponent()
        if parent.path != folder.path {
            model.open(at: parent)
        }
    }

    private func handleSelection(_ url: URL?) {
        guard let url, url != model.fileURL, let node = model.node(at: url), !node.isDirectory else { return }
        model.openDocument(at: url)
    }

    private var noFolderView: some View {
        ContentUnavailableView {
            Label("No Folder", systemImage: "folder")
        } description: {
            Text("Choose a folder to browse, or open a document directly.")
        } actions: {
            Button("Choose…") { model.openPanel() }
        }
    }
}
