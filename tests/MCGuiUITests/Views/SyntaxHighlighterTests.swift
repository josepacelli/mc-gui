import Testing
import SwiftUI
@testable import MCGuiUI

/// Unit tests for `SyntaxHighlighter.highlight` (FV-02): a heuristic, single-line-scoped
/// highlighter - not a real tokenizer, so these check the specific comment/string/
/// keyword/number cases it's designed for rather than exhaustive language grammar.
@Suite("SyntaxHighlighter")
struct SyntaxHighlighterTests {

    /// The foreground color SwiftUI applied to the run whose text exactly matches
    /// `substring`, or `nil` if no such run exists or it has no color attribute.
    private func color(of substring: String, in result: AttributedString) -> Color? {
        for run in result.runs where String(result[run.range].characters) == substring {
            return run.foregroundColor
        }
        return nil
    }

    @Test("plain text with no special tokens preserves the exact text")
    func plainTextPreservesText() {
        let result = SyntaxHighlighter.highlight("hello world")

        #expect(String(result.characters) == "hello world")
    }

    @Test("an empty line produces an empty result")
    func emptyLineProducesEmptyResult() {
        let result = SyntaxHighlighter.highlight("")

        #expect(String(result.characters).isEmpty)
    }

    @Test("a known keyword is colored purple")
    func keywordIsColoredPurple() {
        let result = SyntaxHighlighter.highlight("if x > 0 {")

        #expect(color(of: "if", in: result) == .purple)
    }

    @Test("a non-keyword identifier has no color")
    func nonKeywordIsUncolored() {
        let result = SyntaxHighlighter.highlight("myVariable")

        #expect(color(of: "myVariable", in: result) == nil)
    }

    @Test("a double-quoted string literal is colored red")
    func stringLiteralIsColoredRed() {
        let result = SyntaxHighlighter.highlight(#"let s = "hello""#)

        #expect(color(of: "\"hello\"", in: result) == .red)
    }

    @Test("an escaped quote inside a string does not end it early")
    func escapedQuoteStaysInsideString() {
        let result = SyntaxHighlighter.highlight(#"let s = "a\"b""#)

        #expect(color(of: "\"a\\\"b\"", in: result) == .red)
    }

    @Test("a line comment colors the rest of the line from the prefix onward")
    func lineCommentColorsRestOfLine() {
        let result = SyntaxHighlighter.highlight("let x = 1 // comment here")

        #expect(color(of: "// comment here", in: result) == .secondary)
    }

    @Test("a '#' line comment (Python/shell-style) also colors the rest of the line")
    func hashCommentColorsRestOfLine() {
        let result = SyntaxHighlighter.highlight("x = 1 # comment")

        #expect(color(of: "# comment", in: result) == .secondary)
    }

    @Test("a numeric literal is colored teal")
    func numericLiteralIsColoredTeal() {
        let result = SyntaxHighlighter.highlight("let x = 42")

        #expect(color(of: "42", in: result) == .teal)
    }
}
