import Combine
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// A node in the sidebar file tree. `children` is nil for files and for empty
/// directories (so they render as leaves).
struct FileNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let children: [FileNode]?

    var id: URL { url }
}

/// File-level constants, outside the actor-isolated model so the nonisolated
/// tree builder can read them.
private enum ScanRules {
    static let markdownExtensions = ["md", "markdown", "mdown", "mdwn", "mkd", "txt"]
    static let skippedDirectoryNames = [
        "node_modules", "Pods", "DerivedData", "build", "dist", "vendor", "target",
    ]
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    // Document
    @Published private(set) var fileURL: URL?
    @Published private(set) var markdownText = ""
    @Published private(set) var documentName = ""
    @Published private(set) var loadError: String?
    @Published private(set) var sections: [DocumentSection] = []

    // Sidebar
    @Published private(set) var folderURL: URL?
    @Published private(set) var sidebarItems: [FileNode] = []

    // Viewer state
    @Published var showsSource = false
    @Published var sidebarVisibility: NavigationSplitViewVisibility = .all
    @Published var contentFontSize: Double {
        didSet { UserDefaults.standard.set(contentFontSize, forKey: Self.fontSizeKey) }
    }
    @Published var appearance: AppearancePreference {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    private var fileWatcher: DispatchSourceFileSystemObject?

    private static let fontSizeKey = "contentFontSize"
    private static let appearanceKey = "appearance"
    private static let folderKey = "lastFolder"

    private init() {
        let defaults = UserDefaults.standard
        let storedSize = defaults.object(forKey: Self.fontSizeKey) as? Double ?? 17
        contentFontSize = min(32, max(11, storedSize))
        appearance = AppearancePreference(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "") ?? .system
        if let path = defaults.string(forKey: Self.folderKey) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                setFolder(url)
            }
        }
    }

    // MARK: - Opening

    func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL ?? fileURL?.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(at: url)
    }

    /// Entry point for every way a path enters the app: open panel, drag and drop,
    /// Finder/dock activation, recents.
    func open(at url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            loadError = "“\(url.lastPathComponent)” could not be found."
            return
        }
        if isDirectory.boolValue {
            setFolder(url)
        } else {
            openDocument(at: url)
        }
    }

    func openDocument(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            fileWatcher?.cancel()
            fileWatcher = nil
            fileURL = url
            documentName = url.lastPathComponent
            loadError = nil
            applyMarkdown(text)
            setFolder(url.deletingLastPathComponent())
            watchFile(at: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            loadError = "Could not read “\(url.lastPathComponent)”: \(error.localizedDescription)"
        }
    }

    func bumpFontSize(_ delta: Double) {
        contentFontSize = min(32, max(11, contentFontSize + delta))
    }

    func toggleSidebar() {
        sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly
    }

    private func applyMarkdown(_ text: String) {
        markdownText = text
        sections = DocumentSplitter.split(text)
    }

    // MARK: - Sidebar folder

    func setFolder(_ url: URL) {
        folderURL = url
        sidebarItems = []
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
        Task.detached(priority: .userInitiated) { [weak self] in
            let nodes = AppModel.buildTree(at: url, depth: 0)
            await self?.applyTree(nodes, for: url)
        }
    }

    func refreshFolder() {
        guard let folderURL else { return }
        setFolder(folderURL)
    }

    private func applyTree(_ nodes: [FileNode], for url: URL) {
        guard folderURL == url else { return }
        sidebarItems = nodes
    }

    /// Depth-limited, hidden-and-vendor-directory-skipping recursive listing.
    nonisolated private static func buildTree(at directory: URL, depth: Int) -> [FileNode] {
        guard depth < 7 else { return [] }
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []

        var nodes: [FileNode] = []
        for child in sorted(contents) {
            let name = child.lastPathComponent
            if name.hasPrefix(".") { continue }
            if ScanRules.skippedDirectoryNames.contains(name.lowercased()) { continue }

            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                let children = buildTree(at: child, depth: depth + 1)
                nodes.append(
                    FileNode(url: child, name: name, isDirectory: true, children: children.isEmpty ? nil : children)
                )
            } else if ScanRules.markdownExtensions.contains(child.pathExtension.lowercased()) {
                nodes.append(FileNode(url: child, name: name, isDirectory: false, children: nil))
            }
        }
        return nodes
    }

    private nonisolated static func sorted(_ urls: [URL]) -> [URL] {
        urls.sorted { lhs, rhs in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    func node(at url: URL) -> FileNode? {
        func search(_ nodes: [FileNode]) -> FileNode? {
            for node in nodes {
                if node.id == url { return node }
                if let child = search(node.children ?? []) { return child }
            }
            return nil
        }
        return search(sidebarItems)
    }

    // MARK: - File watching

    private func watchFile(at url: URL) {
        fileWatcher?.cancel()
        fileWatcher = nil
        let descriptor = Darwin.open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.handleFileEvent() }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        fileWatcher = source
    }

    /// Rename events invalidate the descriptor, so the watcher is re-armed after
    /// every event; the document is re-read only when its contents changed.
    private func handleFileEvent() {
        guard let url = fileURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        if let fresh = try? String(contentsOf: url, encoding: .utf8), fresh != markdownText {
            applyMarkdown(fresh)
        }
        watchFile(at: url)
    }
}
