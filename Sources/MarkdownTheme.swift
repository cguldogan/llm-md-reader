import MarkdownUI
import Splash
import SwiftUI

enum ReaderTheme {
    /// GitHub-flavored look; heading sizes are `em`-based, so scaling the base
    /// text size scales the whole document.
    static func markdown(bodySize: Double) -> MarkdownUI.Theme {
        MarkdownUI.Theme.gitHub
            .text {
                FontSize(bodySize)
            }
    }
}

/// Highlights fenced code blocks with Splash. The Splash theme font is ignored;
/// typefaces come from the markdown theme.
struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let highlighter: SyntaxHighlighter<TextOutputFormat>

    init(colorScheme: ColorScheme) {
        let theme: Splash.Theme = colorScheme == .dark
            ? .wwdc17(withFont: .init(size: 13))
            : .sunset(withFont: .init(size: 13))
        self.highlighter = SyntaxHighlighter(format: TextOutputFormat(theme: theme))
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        guard let language, !language.isEmpty else { return Text(code) }
        return highlighter.highlight(code)
    }
}

/// Turns Splash tokens into SwiftUI `Text` runs colored by the active theme.
private struct TextOutputFormat: OutputFormat {
    let theme: Splash.Theme

    func makeBuilder() -> Builder {
        Builder(theme: theme)
    }

    struct Builder: OutputBuilder {
        let theme: Splash.Theme
        private var parts: [Text] = []

        mutating func addToken(_ token: String, ofType type: TokenType) {
            let color = theme.tokenColors[type] ?? theme.plainTextColor
            parts.append(Text(token).foregroundColor(Color(color)))
        }

        mutating func addPlainText(_ text: String) {
            parts.append(Text(text).foregroundColor(Color(theme.plainTextColor)))
        }

        mutating func addWhitespace(_ text: String) {
            parts.append(Text(text))
        }

        func build() -> Text {
            parts.reduce(Text(""), +)
        }
    }
}
