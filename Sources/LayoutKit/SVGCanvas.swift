import Foundation

// Minimal SVG canvas to snapshot a Scene. This is for tests and simple previews.
public final class SVGCanvas: Canvas {
    private var commands: [String] = []
    private var stackDepth: Int = 0
    private let width: Double
    private let height: Double

    public init(width: Double, height: Double) {
        self.width = width; self.height = height
    }

    public func save() { stackDepth += 1; commands.append("<g>") }
    public func restore() { if stackDepth > 0 { stackDepth -= 1; commands.append("</g>") } }
    public func transform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) {
        commands.append(String(format: "<g transform=\"matrix(%g,%g,%g,%g,%g,%g)\">", a,b,c,d,e,f))
    }
    public func drawPath(_ path: Path, style: Style) {
        let d = Self.svgPathData(path)
        let stroke = style.stroke ?? "none"
        let fill = style.fill ?? "none"
        let lw = style.lineWidth
        commands.append("<path d=\"\(d)\" stroke=\"\(stroke)\" fill=\"\(fill)\" stroke-width=\"\(lw)\" />")
    }
    public func drawText(_ run: TextRun) {
        // Basic text run using code points; dx/dy applied per glyph via tspans
        var parts: [String] = []
        for g in run.glyphs {
            let scalar = UnicodeScalar(g.codePoint) ?? "?"
            let ch = String(scalar)
            let dx = g.dx
            let dy = g.dy
            parts.append("<tspan dx=\"\(dx)\" dy=\"\(dy)\">\(Self.escape(ch))</tspan>")
        }
        let font = run.fontFamily
        let size = run.fontSizeSP // SP; tests rely on structure, not pixel-perfect scaling
        commands.append("<text font-family=\"\(Self.escape(font))\" font-size=\"\(size)\">\n\(parts.joined())\n</text>")
    }

    public func svgString() -> String {
        var out = ""; out.reserveCapacity(1024)
        out += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        out += "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\">\n"
        out += commands.joined(separator: "\n")
        // Close any open groups from transform/save
        while stackDepth > 0 { out += "</g>\n"; stackDepth -= 1 }
        out += "\n</svg>\n"
        return out
    }

    private static func svgPathData(_ p: Path) -> String {
        var parts: [String] = []
        for seg in p.segments {
            switch seg {
            case .move(let x, let y): parts.append(String(format: "M %g %g", x, y))
            case .line(let x, let y): parts.append(String(format: "L %g %g", x, y))
            case .quad(let cx, let cy, let x, let y): parts.append(String(format: "Q %g %g %g %g", cx, cy, x, y))
            case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
                parts.append(String(format: "C %g %g %g %g %g %g", c1x, c1y, c2x, c2y, x, y))
            case .close: parts.append("Z")
            }
        }
        return parts.joined(separator: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

