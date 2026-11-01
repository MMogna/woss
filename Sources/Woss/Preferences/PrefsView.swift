import SwiftUI
import WossCore

// MARK: - Icons

/// Mini screen showing where a layout goes. For a loop, all steps are drawn faintly and the
/// current step strongly; hover the row and it plays through the steps.
struct RegionIcon: View {
    let rects: [RelRect]
    let animate: Bool

    private static let stepSeconds = 0.7

    var body: some View {
        TimelineView(.animation(minimumInterval: RegionIcon.stepSeconds, paused: !(animate && rects.count > 1))) { context in
            let step = currentStep(at: context.date)
            Canvas { ctx, size in
                let frame = CGRect(origin: .zero, size: size)
                let outline = Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
                ctx.fill(outline, with: .color(Color.primary.opacity(0.06)))
                ctx.stroke(outline, with: .color(Color.primary.opacity(0.3)), lineWidth: 1)

                let area = frame.insetBy(dx: 3, dy: 3)
                for (i, r) in rects.enumerated() where i != step {
                    ctx.fill(RegionIcon.path(for: r, in: area), with: .color(Color.accentColor.opacity(0.3)))
                }
                if step < rects.count {
                    ctx.fill(RegionIcon.path(for: rects[step], in: area), with: .color(Color.accentColor.opacity(0.95)))
                }
            }
        }
        .frame(width: 44, height: 30)
    }

    private func currentStep(at date: Date) -> Int {
        guard animate, rects.count > 1 else { return 0 }
        let tick = Int(date.timeIntervalSinceReferenceDate / RegionIcon.stepSeconds)
        return tick % rects.count
    }

    /// Layout y is measured from the bottom; SwiftUI draws from the top, so flip it.
    private static func path(for r: RelRect, in area: CGRect) -> Path {
        let rx = CGFloat(r.x)
        let ry = CGFloat(r.y)
        let rw = CGFloat(r.w)
        let rh = CGFloat(r.h)
        let x: CGFloat = area.minX + rx * area.width
        let flipped: CGFloat = 1 - ry - rh
        let y: CGFloat = area.minY + flipped * area.height
        let rect = CGRect(x: x, y: y, width: rw * area.width, height: rh * area.height)
        return Path(rect.insetBy(dx: 0.75, dy: 0.75))
    }
}

/// Icon for the resize actions: a solid window and a dashed outline of what it grows into.
struct ResizeIcon: View {
    enum Mode { case width, height, both }
    let mode: Mode

    var body: some View {
        Canvas { ctx, size in
            let frame = CGRect(origin: .zero, size: size)
            let outline = Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
            ctx.fill(outline, with: .color(Color.primary.opacity(0.06)))
            ctx.stroke(outline, with: .color(Color.primary.opacity(0.3)), lineWidth: 1)

            let growsWide = (mode == .width || mode == .both)
            let growsTall = (mode == .height || mode == .both)

            let innerW: CGFloat = growsWide ? 14 : 26
            let innerH: CGFloat = growsTall ? 9 : 17
            let outerW: CGFloat = growsWide ? 30 : innerW
            let outerH: CGFloat = growsTall ? 20 : innerH
            let cx = size.width / 2
            let cy = size.height / 2

            let outer = CGRect(x: cx - outerW / 2, y: cy - outerH / 2, width: outerW, height: outerH)
            let inner = CGRect(x: cx - innerW / 2, y: cy - innerH / 2, width: innerW, height: innerH)

            ctx.stroke(Path(roundedRect: outer, cornerRadius: 2),
                       with: .color(Color.primary.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            ctx.fill(Path(roundedRect: inner, cornerRadius: 2), with: .color(Color.accentColor.opacity(0.95)))
        }
        .frame(width: 44, height: 30)
    }
}

/// Two windows with a double arrow between them.
struct SwapIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let frame = CGRect(origin: .zero, size: size)
            let outline = Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
            ctx.fill(outline, with: .color(Color.primary.opacity(0.06)))
            ctx.stroke(outline, with: .color(Color.primary.opacity(0.3)), lineWidth: 1)

            let left = CGRect(x: 5, y: 8, width: 12, height: 14)
            let right = CGRect(x: 27, y: 8, width: 12, height: 14)
            ctx.fill(Path(roundedRect: left, cornerRadius: 2), with: .color(Color.accentColor.opacity(0.95)))
            ctx.fill(Path(roundedRect: right, cornerRadius: 2), with: .color(Color.accentColor.opacity(0.35)))

            var arrows = Path()
            arrows.move(to: CGPoint(x: 20, y: 15))
            arrows.addLine(to: CGPoint(x: 24, y: 15))
            arrows.move(to: CGPoint(x: 22, y: 12.5))
            arrows.addLine(to: CGPoint(x: 24, y: 15))
            arrows.addLine(to: CGPoint(x: 22, y: 17.5))
            ctx.stroke(arrows, with: .color(Color.primary.opacity(0.7)), lineWidth: 1.2)
        }
        .frame(width: 44, height: 30)
    }
}

/// 2x2 grid of windows.
struct TileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let frame = CGRect(origin: .zero, size: size)
            let outline = Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
            ctx.fill(outline, with: .color(Color.primary.opacity(0.06)))
            ctx.stroke(outline, with: .color(Color.primary.opacity(0.3)), lineWidth: 1)

            let cells = [
                CGRect(x: 5, y: 5, width: 16, height: 9),
                CGRect(x: 23, y: 5, width: 16, height: 9),
                CGRect(x: 5, y: 16, width: 16, height: 9),
                CGRect(x: 23, y: 16, width: 16, height: 9),
            ]
            for (i, cell) in cells.enumerated() {
                let opacity = (i == 0) ? 0.95 : 0.4
                ctx.fill(Path(roundedRect: cell, cornerRadius: 2), with: .color(Color.accentColor.opacity(opacity)))
            }
        }
        .frame(width: 44, height: 30)
    }
}

// MARK: - Cards

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}

/// One shortcut: icon, name, optional subtitle, and the key field on the right.
struct ShortcutCard<Icon: View>: View {
    let title: String
    let subtitle: String?
    let help: String
    let icon: (Bool) -> Icon
    @Binding var hotkey: String

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            icon(hovering)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            KeyCaptureField(hotkey: $hotkey)
                .frame(width: 96, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(hovering ? 0.09 : 0.05))
        )
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Window content

struct PrefsView: View {
    @ObservedObject var model: PrefsModel
    let onSave: () -> Void
    let onCancel: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(PrefsModel.sections, id: \.self) { section in
                        layoutSection(section)
                    }
                    resizeSection
                    toolsSection
                }
                .padding(20)
            }

            Divider()
            footer
        }
        .frame(minWidth: 760, minHeight: 480)
    }

    @ViewBuilder
    private func layoutSection(_ section: String) -> some View {
        let rowIndices = model.indices(in: section)
        if !rowIndices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: section)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(rowIndices, id: \.self) { i in
                        layoutCard(index: i)
                    }
                }
            }
        }
    }

    private func layoutCard(index i: Int) -> some View {
        let row = model.layoutRows[i]
        return ShortcutCard(
            title: row.title,
            subtitle: row.isLoop ? "↻ Loops through \(row.layouts.count) positions" : nil,
            help: row.isLoop ? row.stepNames : row.title,
            icon: { hovering in RegionIcon(rects: row.rects, animate: hovering) },
            hotkey: $model.layoutRows[i].hotkey
        )
    }

    private var resizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Resize")
            LazyVGrid(columns: columns, spacing: 8) {
                ShortcutCard(title: "Double Width", subtitle: "Grows the window, stays on screen",
                             help: "Double Width",
                             icon: { _ in ResizeIcon(mode: .width) },
                             hotkey: $model.keys.width)
                ShortcutCard(title: "Double Height", subtitle: "Grows the window, stays on screen",
                             help: "Double Height",
                             icon: { _ in ResizeIcon(mode: .height) },
                             hotkey: $model.keys.height)
                ShortcutCard(title: "Double Size", subtitle: "Grows the window, stays on screen",
                             help: "Double Size",
                             icon: { _ in ResizeIcon(mode: .both) },
                             hotkey: $model.keys.both)
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Windows")
            LazyVGrid(columns: columns, spacing: 8) {
                ShortcutCard(title: "Tidy Windows", subtitle: "Arrange all open windows in a grid",
                             help: "Arranges every visible window into a neat grid, one grid per screen.",
                             icon: { _ in TileIcon() },
                             hotkey: $model.keys.tile)
                ShortcutCard(title: "Swap Windows", subtitle: "Label every window, then pick two",
                             help: "Press the key, then the label of two windows to swap them. Esc cancels.",
                             icon: { _ in SwapIcon() },
                             hotkey: $model.keys.swap)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("↺ Reset Defaults") { model.resetDefaults() }
            Text("Click a key and press a new one · right-click to clear · give two actions the same key to loop between them")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button("Cancel", action: onCancel)
            Button("Save & Close", action: onSave)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}
