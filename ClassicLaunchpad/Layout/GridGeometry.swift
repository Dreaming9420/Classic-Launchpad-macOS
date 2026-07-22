import AppKit

struct GridGeometry: Equatable {
    let columns: Int
    let rows: Int
    let pageCapacity: Int
    let pageCount: Int
    let itemSize: CGSize
    let itemFrames: [CGRect]
    let contentFrame: CGRect

    static func make(
        in bounds: CGRect,
        safeAreaInsets: NSEdgeInsets,
        itemCount: Int
    ) -> GridGeometry {
        let usableBounds = CGRect(
            x: bounds.minX + safeAreaInsets.left,
            y: bounds.minY + safeAreaInsets.top,
            width: max(bounds.width - safeAreaInsets.left - safeAreaInsets.right, 1),
            height: max(bounds.height - safeAreaInsets.top - safeAreaInsets.bottom, 1)
        )
        let horizontalSpace = max(
            usableBounds.width - LaunchpadMetrics.minimumHorizontalMargin * 2,
            LaunchpadMetrics.itemWidth
        )
        let verticalSpace = max(
            usableBounds.height - LaunchpadMetrics.gridTopInset - LaunchpadMetrics.gridBottomInset,
            LaunchpadMetrics.itemHeight
        )
        let columns = min(max(Int(horizontalSpace / GridPitch.horizontal), GridCount.minimumColumns), GridCount.maximumColumns)
        let rows = min(max(Int(verticalSpace / GridPitch.vertical), GridCount.minimumRows), GridCount.maximumRows)
        let capacity = columns * rows
        let pageCount = max(Int(ceil(Double(itemCount) / Double(capacity))), 1)
        let contentWidth = min(horizontalSpace, CGFloat(columns) * GridPitch.horizontal)
        let contentHeight = min(verticalSpace, CGFloat(rows) * GridPitch.vertical)
        let contentFrame = CGRect(
            x: usableBounds.midX - contentWidth / 2,
            y: usableBounds.minY + LaunchpadMetrics.gridTopInset + (verticalSpace - contentHeight) / 2,
            width: contentWidth,
            height: contentHeight
        )
        let horizontalGap = columns > 1
            ? (contentWidth - CGFloat(columns) * LaunchpadMetrics.itemWidth) / CGFloat(columns - 1)
            : 0
        let verticalGap = rows > 1
            ? (contentHeight - CGFloat(rows) * LaunchpadMetrics.itemHeight) / CGFloat(rows - 1)
            : 0

        var frames: [CGRect] = []
        for index in 0..<capacity {
            let row = index / columns
            let column = index % columns
            frames.append(CGRect(
                x: contentFrame.minX + CGFloat(column) * (LaunchpadMetrics.itemWidth + horizontalGap),
                y: contentFrame.minY + CGFloat(row) * (LaunchpadMetrics.itemHeight + verticalGap),
                width: LaunchpadMetrics.itemWidth,
                height: LaunchpadMetrics.itemHeight
            ))
        }

        return GridGeometry(
            columns: columns,
            rows: rows,
            pageCapacity: capacity,
            pageCount: pageCount,
            itemSize: CGSize(width: LaunchpadMetrics.itemWidth, height: LaunchpadMetrics.itemHeight),
            itemFrames: frames,
            contentFrame: contentFrame
        )
    }
}

private enum GridPitch {
    static let horizontal: CGFloat = 168
    static let vertical: CGFloat = 132
}

private enum GridCount {
    static let minimumColumns = 5
    static let maximumColumns = 9
    static let minimumRows = 3
    static let maximumRows = 6
}
