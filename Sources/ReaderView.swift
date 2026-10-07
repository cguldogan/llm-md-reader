import MarkdownUI
import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsTableOfContents = false

    var body: some View {
        ScrollViewReader { proxy in
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(model.fileURL?.lastPathComponent ?? "Markdown Reader")
                .toolbar { toolbar(proxy) }
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    Task { @MainActor in model.open(at: url) }
                    return true
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.fileURL == nil {
            emptyState
        } else if model.showsSource {
            sourceView
        } else {
            renderedView
        }
    }

    // MARK: - Rendered

    private var renderedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.sections, id: \.id) { section in
                    chunk(section)
                        .id(section.id)
                }
                Color.clear.frame(height: 48)
            }
        }
    }

    private func chunk(_ section: DocumentSection) -> some View {
        Markdown(section.markdown, baseURL: model.folderURL, imageBaseURL: model.folderURL)
            .markdownTheme(ReaderTheme.markdown(bodySize: model.contentFontSize))
            .markdownCodeSyntaxHighlighter(SplashCodeSyntaxHighlighter(colorScheme: colorScheme))
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .center)
            .textSelection(.enabled)
    }

    // MARK: - Source

    private var sourceView: some View {
        ScrollView {
            Text(model.markdownText)
                .font(.system(size: 12, design: .monospaced))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .textSelection(.enabled)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Document", systemImage: "doc.richtext")
        } description: {
            Text("Open a Markdown file or a folder, or drop one here.")
        } actions: {
            Button("Choose…") { model.openPanel() }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(_ proxy: ScrollViewProxy) -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                model.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle Sidebar")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showsTableOfContents = true
            } label: {
                Image(systemName: "list.bullet.indent")
            }
            .disabled(model.showsSource || !model.sections.contains { $0.level != nil })
            .help("Table of Contents")
            .popover(isPresented: $showsTableOfContents) {
                TOCView(entries: DocumentSplitter.tableOfContents(in: model.sections)) { id in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }

            Picker("View", selection: $model.showsSource) {
                Text("Preview").tag(false)
                Text("Source").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .help("Toggle Preview and Source")

            Menu {
                Button("Increase") { model.bumpFontSize(1) }
                Button("Decrease") { model.bumpFontSize(-1) }
                Divider()
                ForEach([12, 14, 16, 18, 21, 24, 28], id: \.self) { size in
                    Button("\(size) pt") { model.contentFontSize = Double(size) }
                }
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("Text Size")

            Picker("Appearance", selection: $model.appearance) {
                ForEach(AppearancePreference.allCases) { preference in
                    Label(preference.label, systemImage: iconName(for: preference))
                        .tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .help("Appearance")
        }
    }

    private func iconName(for preference: AppearancePreference) -> String {
        switch preference {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

private struct TOCView: View {
    let entries: [TableOfContentsEntry]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if entries.isEmpty {
                Text("No headings")
                    .foregroundStyle(.secondary)
                    .padding(20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry.id)
                                dismiss()
                            } label: {
                                Text(entry.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, CGFloat(entry.level - 1) * 14)
                                    .padding(.vertical, 5)
                                    .padding(.trailing, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 320, height: 380)
    }
}
