# MarkdownReader — Demo Document

This file exists so you can immediately verify the reader. Open it via **File ▸ Open…**, drag it onto the window, or drop it on the Dock icon.

## Formatting

Regular **bold**, *italic*, `inline code`, and a [link](https://example.com) — plus a blockquote:

> Readers render blockquotes with the classic left rule.
> Second line.

- Bullet one
- Bullet two
  - Nested bullet
- [ ] A task list item
- [x] A completed task

1. First
2. Second

### Tables

| Feature | Status |
| ------- | ------ |
| GFM tables | ✓ |
| Task lists | ✓ |

### A long code block

```swift
struct Reader {
    let name: String = "MarkdownReader"

    func render(markdown: String) {
        let sections = markdown.splitAtHeadings()
        print("Rendering \(sections.count) sections…")
    }
}
```

```bash
# non-Swift code gets conservative highlighting
xcodebuild -scheme MarkdownReader build
```

### The Third Heading

Text after a heading, to have several table-of-contents entries.

#### And a Fourth

More text.

##### Fifth

Fin.
