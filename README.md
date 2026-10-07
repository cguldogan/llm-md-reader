# MarkdownReader

[![CI](https://github.com/cguldogan/llm-md-reader/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/cguldogan/llm-md-reader/actions/workflows/ci.yml)

A native macOS markdown reader built with SwiftUI. Renders GitHub-flavored markdown
(headings, tables, task lists, syntax-highlighted code blocks) with a live-updating
preview, folder sidebar, and table-of-contents navigation.

## Download

Every version tag is built automatically — grab the latest app from
[Releases](https://github.com/cguldogan/llm-md-reader/releases): download
`MarkdownReader-<version>.zip` (or the `.dmg`), unpack, and drag the app to
Applications. Builds are ad-hoc signed, so if macOS blocks the first launch,
right-click the app and choose **Open**.

## Build & run

```sh
xcodegen generate
xcodebuild -project MarkdownReader.xcodeproj -scheme MarkdownReader \
  -configuration Debug -derivedDataPath .build build
open .build/Build/Products/Debug/MarkdownReader.app
```

Tests:

```sh
xcodebuild -project MarkdownReader.xcodeproj -scheme MarkdownReader \
  -derivedDataPath .build test
```

## Features

- Open via dialog (⌘O), drag & drop, Dock-icon drop, or double-click in Finder
  (registered for `.md`/`.markdown`/… as a viewer).
- Folder sidebar with recursive tree (hidden/vendored dirs skipped); sidebar roots
  at a opened file's parent.
- Preview ⇄ Source (⌘1/⌘2), live reload when the file changes on disk.
- Table of contents popover; entries scroll the preview to the heading.
- System light/dark with manual override; adjustable text size (⌘+/⌘−).
- Relative image/link resolution against the document's folder; external links
  open in the default browser.

## Layout

```
project.yml                   xcodegen manifest (app + tests, entitlements, plist)
Sources/
  MarkdownReaderApp.swift     @main, menu commands, Apple event handler for cold-start open
  ContentView.swift           NavigationSplitView shell
  AppModel.swift              document/folder state, file watcher, prefs, sidebar tree
  FileTreeView.swift          sidebar outline + header controls
  ReaderView.swift            preview/source, TOC popover, empty state, drop target
  MarkdownTheme.swift         MarkdownUI theme + Splash syntax-highlighting bridge
  TableOfContents.swift       heading splitter / slug / TOC extraction (pure Foundation)
Tests/
  DocumentSplitterTests.swift unit tests for the splitter
```

## Implementation notes

- Rendering uses [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1;
  code highlighting via [Splash](https://github.com/JohnSundell/Splash) (`sunset` light /
  `wwdc17` dark token palettes).
- Anchor scrolling is implemented by splitting the document at headings
  (fence-aware) and rendering one `Markdown` view per section, so TOC ids are
  owned by this app, not the renderer.
- Sandboxed with read-only user-selected file access; no network except for
  remote images inside documents.
