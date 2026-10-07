import Foundation

enum Whitespace {
    /// Trims `result` and re-applies the leading/trailing whitespace of `original`,
    /// so e.g. a selection that ended with a newline still ends with one.
    static func preserving(of original: String, in result: String) -> String {
        let core = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let leading = String(original.prefix(while: \.isWhitespace))
        let trailing = String(original.reversed().prefix(while: \.isWhitespace).reversed())
        return leading + core + trailing
    }
}
