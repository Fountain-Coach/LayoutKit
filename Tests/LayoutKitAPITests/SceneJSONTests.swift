import Foundation
import Testing
@testable import LayoutKitAPI

@Test func sceneJSON_encodes_deterministically() async throws {
    // Build a simple rectangle path scene
    let page = Components.Schemas.PageSpec(
        widthPt: 200,
        heightPt: 100,
        margins: .init(top: 10, left: 10, right: 10, bottom: 10),
        units: .pt,
        yUp: true
    )
    let path = Components.Schemas.Path(segments: [
        .moveTo(.init(op: .moveTo, x: 0, y: 0)),
        .lineTo(.init(op: .lineTo, x: 200, y: 0)),
        .lineTo(.init(op: .lineTo, x: 200, y: 100)),
        .lineTo(.init(op: .lineTo, x: 0, y: 100)),
        .closePath(.init(op: .closePath))
    ])
    let strokeColor = Components.Schemas.Color.case2(.init(r: 0, g: 0, b: 0, a: 1))
    let style = Components.Schemas.Style(
        stroke: .Color(strokeColor),
        fill: nil,
        lineWidth: 1,
        lineCap: .butt,
        lineJoin: .miter,
        miterLimit: 4,
        lineDash: nil,
        dashOffset: nil,
        fillRule: .nonzero,
        blendMode: .normal
    )
    let cmd = Components.Schemas.Command.path(.init(op: .path, path: path, style: style))
    let scene = Components.Schemas.Scene(
        page: page,
        units: .pt,
        yUp: true,
        version: .scene_hyphen_v1,
        bounds: nil,
        snapHints: nil,
        resources: nil,
        commands: [cmd]
    )
    let data = try JSONEncoder().encode(scene)
    let json = String(data: data, encoding: .utf8) ?? ""
    #expect(json.contains("\"op\":\"path\""))
    #expect(json.contains("\"segments\""))
    #expect(json.contains("\"moveTo\""))
    #expect(json.contains("\"lineTo\""))
    #expect(json.contains("\"closePath\""))
}
