import Testing
@testable import LayoutKit

@Test func svgCanvas_renders_basic_scene() async throws {
    // Given a page
    let page = PageSpec(widthPt: 200, heightPt: 100)
    let scene = LayoutEngine.layout(page: page)
    // When rendering to SVG
    let canvas = SVGCanvas(width: page.widthPt, height: page.heightPt)
    SceneRenderer.render(scene, on: canvas)
    let svg = canvas.svgString()
    // Then the SVG contains root and at least two paths (page + margin box)
    #expect(svg.contains("<svg"))
    #expect(svg.contains("<path d=\"M 0 0 L 200 0 L 200 100 L 0 100 Z\""))
}

