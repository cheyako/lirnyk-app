import Testing
@testable import Lirnyk

struct WhitespaceTests {
    @Test(arguments: [
        ("helo wrld", "hello world", "hello world"),
        ("helo\n", "hello", "hello\n"),
        ("  helo  ", "hello", "  hello  "),
        ("\n\nhelo\n", "  hello \n", "\n\nhello\n"),
        ("helo", "\nhello\n\n", "hello"),
    ])
    func preservesOuterWhitespace(original: String, result: String, expected: String) {
        #expect(Whitespace.preserving(of: original, in: result) == expected)
    }
}
