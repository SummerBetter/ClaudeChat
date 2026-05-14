import SwiftUI

enum MarkdownBlock: Equatable {
    case paragraph(String)
    case codeBlock(String, String)  // language, code
    case table(headers: [String], rows: [[String]])
    case divider
}

struct MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                i += 1 // skip closing ```
                blocks.append(.codeBlock(lang, codeLines.joined(separator: "\n")))
                continue
            }

            // Divider
            if line.trimmingCharacters(in: CharacterSet(charactersIn: "-*_ ")).isEmpty,
               line.contains("---") || line.contains("***") {
                blocks.append(.divider)
                i += 1
                continue
            }

            // Table detection: current line has | and next line is separator
            if line.contains("|"), i + 1 < lines.count,
               lines[i + 1].contains("|"), lines[i + 1].contains("---") {
                let headers = parseTableRow(line)
                i += 2 // skip separator
                var rows: [[String]] = []
                while i < lines.count && lines[i].contains("|") {
                    rows.append(parseTableRow(lines[i]))
                    i += 1
                }
                if !headers.isEmpty {
                    blocks.append(.table(headers: headers, rows: rows))
                }
                continue
            }

            // Paragraph: collect contiguous non-empty lines
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.hasPrefix("```") || l.hasPrefix("|") && i + 1 < lines.count && lines[i + 1].contains("---") {
                    break
                }
                if l.trimmingCharacters(in: CharacterSet(charactersIn: "-*_ ")).isEmpty,
                   l.contains("---") || l.contains("***") {
                    break
                }
                if l.isEmpty && !paraLines.isEmpty {
                    // Separating empty line could start a new paragraph, but
                    // check if next line is a list item (continuation)
                    if i + 1 < lines.count {
                        let next = lines[i + 1]
                        if next.trimmingPrefix(while: { $0 == " " }).hasPrefix("- ")
                            || next.trimmingPrefix(while: { $0 == " " }).hasPrefix("* ")
                            || (Int(next.trimmingPrefix(while: { $0.isNumber && $0 != "." }).prefix(1)) != nil) {
                            paraLines.append(l)
                            i += 1
                            continue
                        }
                    }
                    break
                }
                paraLines.append(l)
                i += 1
            }
            let joined = paraLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(.paragraph(joined))
            }
        }

        return blocks
    }

    private static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "| "))
        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}