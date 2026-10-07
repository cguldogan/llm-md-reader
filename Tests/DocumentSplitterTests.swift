import XCTest
@testable import MarkdownReader

final class DocumentSplitterTests: XCTestCase {
    func testSplitsPreambleAndHeadings() {
        let markdown = """
        intro line

        # One
        body one

        ## Two
        body two
        """
        let sections = DocumentSplitter.split(markdown)

        XCTAssertEqual(sections.count, 3)
        XCTAssertEqual(sections[0].id, "preamble")
        XCTAssertNil(sections[0].level)
        XCTAssertTrue(sections[0].markdown.contains("intro line"))

        XCTAssertEqual(sections[1].id, "one")
        XCTAssertEqual(sections[1].level, 1)
        XCTAssertEqual(sections[1].title, "One")
        XCTAssertTrue(sections[1].markdown.contains("body one"))

        XCTAssertEqual(sections[2].id, "two")
        XCTAssertEqual(sections[2].level, 2)
    }

    func testHeadingLikeLinesInsideFencesAreNotSplitPoints() {
        let markdown = """
        # Real
        ```swift
        #notAHeading
        let x = 1
        ```
        more
        """
        let sections = DocumentSplitter.split(markdown)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].level, 1)
        XCTAssertTrue(sections[0].markdown.contains("#notAHeading"))
    }

    func testTildeFences() {
        let markdown = """
        # One
        ~~~
        # inside
        ~~~
        # Two
        """
        let sections = DocumentSplitter.split(markdown)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[1].id, "two")
    }

    func testClosingFenceMayBeLongerThanOpeningFence() {
        let markdown = """
        # One
        ````
        ```
        ````
        # Two
        """
        let sections = DocumentSplitter.split(markdown)

        XCTAssertEqual(sections.count, 2)
    }

    func testDuplicateHeadingsGetUniqueSlugs() {
        let markdown = """
        # Setup
        a

        # Setup
        b

        ## Setup
        c
        """
        let sections = DocumentSplitter.split(markdown)
        let ids = sections.map(\.id)

        XCTAssertEqual(ids, ["setup", "setup-1", "setup-2"])
    }

    func testSlug() {
        XCTAssertEqual(DocumentSplitter.slug("Hello, World!"), "hello-world")
        XCTAssertEqual(DocumentSplitter.slug("Multiple   spaces"), "multiple---spaces")
        XCTAssertEqual(DocumentSplitter.slug("C# & F♯"), "c--f")
        XCTAssertEqual(DocumentSplitter.slug("Résumé — über"), "résumé--über")
        XCTAssertEqual(DocumentSplitter.slug("?!:"), "section")
        XCTAssertEqual(DocumentSplitter.slug("---"), "---")
    }

    func testEmptyAndBlankDocuments() {
        XCTAssertTrue(DocumentSplitter.split("").isEmpty)
        XCTAssertTrue(DocumentSplitter.split("\n\n  \n").isEmpty)
    }

    func testSetextHeadingsDoNotSplit() {
        let markdown = """
        Title
        =====
        body
        """
        let sections = DocumentSplitter.split(markdown)

        XCTAssertEqual(sections.count, 1)
        XCTAssertNil(sections[0].level)
    }

    func testTableOfContentsSkipsPreambleAndCleansTitle() {
        let markdown = """
        plain intro

        # *Big* `Title`
        x

        ## Sub
        y
        """
        let entries = DocumentSplitter.tableOfContents(in: DocumentSplitter.split(markdown))

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "Big Title")
        XCTAssertEqual(entries[0].level, 1)
        XCTAssertEqual(entries[1].id, "sub")
    }

    func testCRLFInput() {
        let sections = DocumentSplitter.split("# A\r\nbody\r\n\r\n## B\r\nx")

        XCTAssertEqual(sections.map(\.id), ["a", "b"])
    }
}
