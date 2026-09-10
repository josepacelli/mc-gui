import SwiftUI

/// A minimal, heuristic syntax highlighter for the text viewer (FV-02): single-line-scoped
/// (no multi-line block-comment tracking) and language-agnostic (one shared keyword set
/// spanning common C-like/Python/shell/SQL-ish languages, not a real per-language grammar).
/// Colors line comments, string literals, keywords, and numeric literals - enough to make
/// source more scannable at a glance, not a real tokenizer/parser.
enum SyntaxHighlighter {
    private static let keywords: Set<String> = [
        "func", "function", "def", "fn", "class", "struct", "enum", "protocol", "interface",
        "trait", "if", "else", "elif", "for", "foreach", "while", "do", "switch", "case",
        "default", "break", "continue", "return", "yield", "import", "include", "require",
        "using", "namespace", "package", "module", "let", "var", "const", "static", "final",
        "public", "private", "protected", "internal", "readonly", "void", "int", "float",
        "double", "bool", "boolean", "string", "char", "byte", "long", "short", "self",
        "this", "super", "true", "false", "null", "nil", "none", "undefined", "try",
        "catch", "finally", "throw", "throws", "raise", "except", "async", "await", "new",
        "delete", "extends", "implements", "override", "abstract", "virtual", "guard",
        "in", "of", "as", "is", "typeof", "instanceof", "lambda", "with", "pass", "and",
        "or", "not", "select", "from", "where", "insert", "update", "table"
    ]

    private static let lineCommentPrefixes = ["//", "#", "--", ";;"]

    /// Highlights one line of source text. `line` should not contain a newline.
    static func highlight(_ line: Substring) -> AttributedString {
        let chars = Array(line)
        guard !chars.isEmpty else { return AttributedString("") }

        var result = AttributedString()
        var i = 0

        func appendRun(_ text: ArraySlice<Character>, color: Color?) {
            guard !text.isEmpty else { return }
            var run = AttributedString(String(text))
            if let color { run.foregroundColor = color }
            result += run
        }

        while i < chars.count {
            if lineCommentPrefixes.contains(where: { matches(chars, at: i, prefix: $0) }) {
                appendRun(chars[i...], color: .secondary)
                break
            }

            let c = chars[i]

            if c == "\"" || c == "'" {
                let quote = c
                var j = i + 1
                while j < chars.count, chars[j] != quote {
                    j += (chars[j] == "\\" && j + 1 < chars.count) ? 2 : 1
                }
                let end = min(j + 1, chars.count)
                appendRun(chars[i..<end], color: .red)
                i = end
                continue
            }

            if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" {
                    j += 1
                }
                let word = chars[i..<j]
                appendRun(word, color: keywords.contains(String(word)) ? .purple : nil)
                i = j
                continue
            }

            if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." {
                    j += 1
                }
                appendRun(chars[i..<j], color: .teal)
                i = j
                continue
            }

            appendRun(chars[i...i], color: nil)
            i += 1
        }

        return result
    }

    private static func matches(_ chars: [Character], at index: Int, prefix: String) -> Bool {
        let prefixChars = Array(prefix)
        guard index + prefixChars.count <= chars.count else { return false }
        for (offset, expected) in prefixChars.enumerated() where chars[index + offset] != expected {
            return false
        }
        return true
    }
}
