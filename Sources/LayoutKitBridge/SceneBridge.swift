import Foundation
import LayoutKit
import LayoutKitAPI

public enum SceneBridge {
    public static func toAPI(_ scene: LayoutKit.Scene) -> Components.Schemas.Scene {
        let apiPage = Components.Schemas.PageSpec(
            widthPt: scene.page.widthPt,
            heightPt: scene.page.heightPt,
            margins: .init(top: scene.page.margins.top, left: scene.page.margins.left, right: scene.page.margins.right, bottom: scene.page.margins.bottom),
            units: .pt,
            yUp: true
        )
        let cmds: [Components.Schemas.Command] = scene.commands.compactMap { cmd in
            switch cmd {
            case .save:
                return .save(.init(op: .save, id: nil))
            case .restore:
                return .restore(.init(op: .restore))
            case let .transform(a,b,c,d,e,f):
                return .transform(.init(op: .transform, a: a, b: b, c: c, d: d, e: e, f: f))
            case let .drawPath(path, style):
                let segments: [Components.Schemas.PathSegment] = path.segments.map { seg in
                    switch seg {
                    case let .move(x, y):
                        return .moveTo(.init(op: .moveTo, x: x, y: y))
                    case let .line(x, y):
                        return .lineTo(.init(op: .lineTo, x: x, y: y))
                    case let .quad(cx, cy, x, y):
                        return .quadTo(.init(op: .quadTo, cx: cx, cy: cy, x: x, y: y))
                    case let .cubic(c1x, c1y, c2x, c2y, x, y):
                        return .cubicTo(.init(op: .cubicTo, c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
                    case .close:
                        return .closePath(.init(op: .closePath))
                    }
                }
                let apiPath = Components.Schemas.Path(segments: segments)
                let apiStyle = Components.Schemas.Style(
                    stroke: style.stroke.map { .Color(.case1($0)) },
                    fill: style.fill.map { .Color(.case1($0)) },
                    strokeOpacity: nil, fillOpacity: nil, lineWidth: style.lineWidth,
                    lineCap: nil, lineJoin: nil, miterLimit: nil, lineDash: nil, dashOffset: nil, fillRule: nil, blendMode: nil
                )
                return .path(.init(op: .path, path: apiPath, style: apiStyle))
            case let .drawText(run):
                let glyphs: Components.Schemas.TextRun.glyphsPayload = run.glyphs.map { g in
                    .init(codePoint: Int(g.codePoint), dx: g.dx, dy: g.dy, advance: nil)
                }
                let apiRun = Components.Schemas.TextRun(
                    x: 0, y: 0, fontRef: nil, fontFamily: run.fontFamily, fontSizePt: Double(run.fontSizeSP) /* approximate */,
                    glyphSet: .unicode, baseline: .alphabetic, dir: .ltr, lang: nil, script: nil, glyphs: glyphs
                )
                return .text(.init(op: .text, run: apiRun))
            }
        }
        return Components.Schemas.Scene(
            page: apiPage, units: .pt, yUp: true, version: .scene_hyphen_v1,
            bounds: nil, snapHints: nil, resources: nil, commands: cmds
        )
    }

    public static func fromAPI(_ api: Components.Schemas.Scene) -> LayoutKit.Scene {
        let page = LayoutKit.PageSpec(
            widthPt: api.page.widthPt, heightPt: api.page.heightPt,
            margins: LayoutKit.Insets(top: api.page.margins?.top ?? 0, left: api.page.margins?.left ?? 0, right: api.page.margins?.right ?? 0, bottom: api.page.margins?.bottom ?? 0)
        )
        let commands: [LayoutKit.Command] = api.commands.compactMap { c in
            switch c {
            case .save:
                return .save
            case .restore:
                return .restore
            case .transform(let t):
                return .transform(a: t.a, b: t.b, c: t.c, d: t.d, e: t.e, f: t.f)
            case .path(let p):
                let segs: [LayoutKit.PathSegment] = p.path.segments.map { s in
                    switch s {
                    case .moveTo(let v): return .move(x: v.x, y: v.y)
                    case .lineTo(let v): return .line(x: v.x, y: v.y)
                    case .quadTo(let v): return .quad(cx: v.cx, cy: v.cy, x: v.x, y: v.y)
                    case .cubicTo(let v): return .cubic(c1x: v.c1x, c1y: v.c1y, c2x: v.c2x, c2y: v.c2y, x: v.x, y: v.y)
                    case .arcTo: return .close // unsupported; degrade
                    case .closePath: return .close
                    }
                }
                let path = LayoutKit.Path(segs)
                let style = LayoutKit.Style(
                    stroke: { if let s = p.style.stroke { if case .Color(let c) = s { switch c { case .case1(let css): return css; case .case2: return nil } } }; return nil }(),
                    fill: { if let f = p.style.fill { if case .Color(let c) = f { switch c { case .case1(let css): return css; case .case2: return nil } } }; return nil }(),
                    lineWidth: p.style.lineWidth ?? 1
                )
                return .drawPath(path: path, style: style)
            case .text(let t):
                let glyphs = t.run.glyphs.map { LayoutKit.Glyph(codePoint: UInt32($0.codePoint), dx: $0.dx ?? 0, dy: $0.dy ?? 0) }
                let run = LayoutKit.TextRun(fontFamily: t.run.fontFamily ?? "System", fontSizeSP: t.run.fontSizePt ?? 12, baseline: t.run.baseline?.rawValue ?? "alphabetic", glyphs: glyphs)
                return .drawText(run: run)
            case .image, .clipPath:
                return nil
            }
        }
        return LayoutKit.Scene(page: page, commands: commands)
    }
}
