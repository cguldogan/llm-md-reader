import Foundation

/// One contiguous chunk of a markdown document: either the text before the first
/// heading ("preamble") or a heading plus everything up to the next heading.
/// Splitting at headings is what powers both the table of contents and anchor
/// scrolling, without relying on renderer-internal anchor ids.
struct DocumentSection: Equatable {
    let id: String
    let level: Int?
    let title: String?
    let markdown: String
}

struct TableOfContentsEntry: Identifiable, Equatable {
    let id: String
    let level: Int
    let title: String
}

enum DocumentSplitter {
    /// Splits markdown into sections at ATX headings (`#`–`######`), ignoring
    /// heading-like lines inside fenced code blocks (``` or ~~~).
    static func split(_ markdown: String) -> [DocumentSection] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var sections: [DocumentSection] = []
        var slugCounts: [String: Int] = [:]
        var chunkLines: [String] = []
        var chunkHeading: (level: Int, title: String)?
        var openFence: (character: Character, length: Int)?

        func flush() {
            let body = chunkLines.joined(separator: "\n")
            defer {
                chunkLines = []
                chunkHeading = nil
            }
            if chunkHeading == nil, body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
            let base = chunkHeading.map { slug($0.title) } ?? "preamble"
            let count = slugCounts[base, default: 0]
            slugCounts[base] = count + 1
            let id = count == 0 ? base : "\(base)-\(count)"
            sections.append(
                DocumentSection(
                    id: id,
                    level: chunkHeading?.level,
                    title: chunkHeading?.title,
                    markdown: body
                )
            )
        }

        for line in lines {
            if let fence = openFence {
                chunkLines.append(line)
                if let spec = fenceSpec(of: line),
                   spec.character == fence.character,
                   spec.count >= fence.length,
                   spec.info.isEmpty
                {
                    openFence = nil
                }
                continue
            }
            if let spec = fenceSpec(of: line) {
                openFence = (spec.character, spec.count)
                chunkLines.append(line)
                continue
            }
            if let heading = parseHeading(line) {
                flush()
                chunkHeading = heading
                chunkLines = [line]
                continue
            }
            chunkLines.append(line)
        }
        flush()

        return sections
    }

    /// GitHub-style anchor slug: lowercase, spaces to hyphens, punctuation dropped.
    static func slug(_ title: String) -> String {
        var result = ""
        for character in title.lowercased() {
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                result.append(character)
            } else if character == " " {
                result.append("-")
            }
        }
        return result.isEmpty ? "section" : result
    }

    static func tableOfContents(in sections: [DocumentSection]) -> [TableOfContentsEntry] {
        sections.compactMap { section in
            guard let level = section.level, let title = section.title else { return nil }
            let plain = title.filter { !"*_~`".contains($0) }
            return TableOfContentsEntry(id: section.id, level: level, title: plain)
        }
    }

    // MARK: - Line parsing

    private struct FenceSpec {
        let character: Character
        let count: Int
        let info: String
    }

    private static func fenceSpec(of line: String) -> FenceSpec? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3, leadingSpaces < line.count else { return nil }
        let index = line.index(line.startIndex, offsetBy: leadingSpaces)
        let rest = line[index...]

        for character in ["`", "~"] {
            let fence = Character(character)
            var count = 0
            for char in rest {
                if char == fence { count += 1 } else { break }
            }
            guard count >= 3 else { continue }
            let info = String(rest.dropFirst(count)).trimmingCharacters(in: .whitespaces)
            return FenceSpec(character: fence, count: count, info: info)
        }
        return nil
    }

    private static let headingPattern = try! NSRegularExpression(
        pattern: #"^ {0,3}(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$"#
    )

    private static func parseHeading(_ line: String) -> (level: Int, title: String)? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = headingPattern.firstMatch(in: line, range: range),
              let titleRange = Range(match.range(at: 2), in: line)
        else { return nil }
        let level = match.range(at: 1).length
        let title = String(line[titleRange]).trimmingCharacters(in: .whitespaces)
        return (level, title)
    }
}
