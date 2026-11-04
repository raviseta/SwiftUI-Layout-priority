import SwiftUI

/// A custom policy: higher priorities appear first, while every cell has equal width.
/// SwiftUI supplies `LayoutSubview.priority`; this layout decides how to use it.
struct PriorityOrderedRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let gap = max(0, spacing)
        let idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let idealWidth = (idealSizes.map(\.width).max() ?? 0) * CGFloat(subviews.count)
            + gap * CGFloat(subviews.count - 1)
        let width = max(0, proposal.width ?? idealWidth)
        let cellWidth = max(0, (width - gap * CGFloat(subviews.count - 1)) / CGFloat(subviews.count))
        let idealHeight = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: proposal.height)).height
        }.max() ?? 0
        return CGSize(width: width, height: max(0, proposal.height ?? idealHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let gap = subviews.count > 1
            ? min(max(0, spacing), bounds.width / CGFloat(subviews.count - 1)) : 0
        let width = max(0, (bounds.width - gap * CGFloat(subviews.count - 1)) / CGFloat(subviews.count))
        let order = subviews.indices.sorted { left, right in
            if subviews[left].priority == subviews[right].priority { return left < right }
            return subviews[left].priority > subviews[right].priority
        }
        for (position, index) in order.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + CGFloat(position) * (width + gap), y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
        }
    }
}
