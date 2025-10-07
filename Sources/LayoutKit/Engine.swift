import Foundation

// Minimal in‑process engine that turns a PageSpec into a Scene. This is a stub
// to validate the spec and Canvas renderers; ScoreKit/RulesKit will drive real content.
public enum LayoutEngine {
    public static func layout(page: PageSpec) -> Scene {
        var cmds: [Command] = []

        // Page border (0,0) .. (w,h) in y‑up
        let w = page.widthPt, h = page.heightPt
        cmds.append(.drawPath(path: Path.rect(x: 0, y: 0, width: w, height: h),
                              style: Style(stroke: "#000", fill: nil, lineWidth: 1)))

        // Margin box
        let m = page.margins
        let mx = m.left, my = m.bottom, mw = w - (m.left + m.right), mh = h - (m.top + m.bottom)
        cmds.append(.drawPath(path: Path.rect(x: mx, y: my, width: mw, height: mh),
                              style: Style(stroke: "#888", fill: nil, lineWidth: 1)))

        return Scene(page: page, commands: cmds)
    }
}

extension Path {
    public static func rect(x: Double, y: Double, width: Double, height: Double) -> Path {
        Path([
            .move(x: x, y: y),
            .line(x: x + width, y: y),
            .line(x: x + width, y: y + height),
            .line(x: x, y: y + height),
            .close
        ])
    }
}

