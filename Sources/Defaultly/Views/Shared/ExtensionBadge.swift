import DefaultlyCore
import SwiftUI

/// `.docx` in a tinted capsule. Text stays primary-colored for contrast; the tint only adds grouping.
struct ExtensionBadge: View {
    let ext: FileExtension
    let tint: Color
    var isLarge = false

    var body: some View {
        Text(verbatim: ext.description)
            .font(.system(isLarge ? .title3 : .caption, design: .monospaced).weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, isLarge ? 10 : 6)
            .padding(.vertical, isLarge ? 6 : 2)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: isLarge ? 8 : 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: isLarge ? 8 : 5, style: .continuous)
                    .strokeBorder(tint.opacity(0.4), lineWidth: 0.5)
            }
    }
}

/// Wraps badges onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(width: bounds.width, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + lineHeight + spacing)
                lineHeight = 0
            }
            positions.append(origin)
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, origin.x - spacing)
        }
        return (CGSize(width: maxX, height: origin.y + lineHeight), positions)
    }
}

/// Badges for a list of formats, capped so long lists stay scannable.
/// Lives inside form rows, so it takes its colors as a parameter instead of reading the environment.
struct FormatBadges: View {
    let formats: [FileFormat]
    let tint: (FileFormat) -> Color
    var limit = 40

    var body: some View {
        FlowLayout {
            ForEach(formats.prefix(limit)) { format in
                ExtensionBadge(ext: format.ext, tint: tint(format))
                    .help(format.displayName)
            }
            if formats.count > limit {
                Text("+\(formats.count - limit) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
