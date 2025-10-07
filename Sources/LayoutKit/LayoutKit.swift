import Foundation
import CoreGraphics

// MARK: - Core model (page + scene)

public struct PageSpec: Sendable, Codable, Equatable {
    public var widthPt: Double
    public var heightPt: Double
    public var margins: Insets
    public init(widthPt: Double, heightPt: Double, margins: Insets = .init(top: 48, left: 36, right: 36, bottom: 48)) {
        self.widthPt = widthPt; self.heightPt = heightPt; self.margins = margins
    }
}

public struct Insets: Sendable, Codable, Equatable {
    public var top: Double, left: Double, right: Double, bottom: Double
    public init(top: Double, left: Double, right: Double, bottom: Double) {
        self.top = top; self.left = left; self.right = right; self.bottom = bottom
    }
}

public enum PathSegment: Sendable, Codable, Equatable { case move(x: Double, y: Double), line(x: Double, y: Double), quad(cx: Double, cy: Double, x: Double, y: Double), cubic(c1x: Double, c1y: Double, c2x: Double, c2y: Double, x: Double, y: Double), close }
public struct Path: Sendable, Codable, Equatable { public var segments: [PathSegment]; public init(_ segments: [PathSegment]) { self.segments = segments } }

public struct Style: Sendable, Codable, Equatable {
    public var stroke: String? // CSS color
    public var fill: String?
    public var lineWidth: Double
    public init(stroke: String? = "#000", fill: String? = nil, lineWidth: Double = 1) { self.stroke = stroke; self.fill = fill; self.lineWidth = lineWidth }
}

public struct Glyph: Sendable, Codable, Equatable {
    public var codePoint: UInt32; public var dx: Double; public var dy: Double
    public init(codePoint: UInt32, dx: Double, dy: Double) { self.codePoint = codePoint; self.dx = dx; self.dy = dy }
}
public struct TextRun: Sendable, Codable, Equatable {
    public var fontFamily: String; public var fontSizeSP: Double; public var baseline: String; public var glyphs: [Glyph]
    public init(fontFamily: String, fontSizeSP: Double, baseline: String, glyphs: [Glyph]) {
        self.fontFamily = fontFamily; self.fontSizeSP = fontSizeSP; self.baseline = baseline; self.glyphs = glyphs
    }
}

public enum Command: Sendable, Codable, Equatable {
    case save
    case restore
    case transform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) // 2D affine
    case drawPath(path: Path, style: Style)
    case drawText(run: TextRun)
}

public struct Scene: Sendable, Codable, Equatable { public var page: PageSpec; public var commands: [Command]
    public init(page: PageSpec, commands: [Command]) { self.page = page; self.commands = commands }
}

// MARK: - Canvas protocol (to be implemented by SDLKit, CoreGraphics, SVG, PDF)

public protocol Canvas {
    func save()
    func restore()
    func transform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double)
    func drawPath(_ path: Path, style: Style)
    func drawText(_ run: TextRun)
}

public enum SceneRenderer {
    public static func render(_ scene: Scene, on canvas: Canvas) {
        for cmd in scene.commands {
            switch cmd {
            case .save: canvas.save()
            case .restore: canvas.restore()
            case let .transform(a,b,c,d,e,f): canvas.transform(a: a, b: b, c: c, d: d, e: e, f: f)
            case let .drawPath(path, style): canvas.drawPath(path, style: style)
            case let .drawText(run): canvas.drawText(run)
            }
        }
    }
}
