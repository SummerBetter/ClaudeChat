import SwiftUI

struct MarkdownBlockView: View {
    let blocks: [MarkdownBlock]
    @State private var copiedCodeId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            if let attr = try? AttributedString(markdown: text) {
                Text(attr)
                    .textSelection(.enabled)
            } else {
                Text(text)
                    .textSelection(.enabled)
            }

        case .codeBlock(let lang, let code):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if !lang.isEmpty {
                        Text(lang)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(code, forType: .string)
                        copiedCodeId = code
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if copiedCodeId == code { copiedCodeId = nil }
                        }
                    } label: {
                        Image(systemName: copiedCodeId == code ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .textSelection(.enabled)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        case .table(let headers, let rows):
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, h in
                        Text(h)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.1))
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { ci, cell in
                            Text(cell)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ri % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

        case .divider:
            Divider()
        }
    }
}