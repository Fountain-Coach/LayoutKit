import Foundation
import OpenAPIRuntime
import HTTPTypes
import LayoutKit
import LayoutKitAPI

// Default API handlers delegating to the in‑process LayoutEngine.
public struct DefaultHandlers: APIProtocol, Sendable {
    public init() {}

    public func post_sol_layout_sol_page(
        _ input: Operations.post_sol_layout_sol_page.Input
    ) async throws -> Operations.post_sol_layout_sol_page.Output {
        // Extract PageSpec from generated types
        let pageIn: Components.Schemas.PageSpec
        switch input.body {
        case .json(let v): pageIn = v
        }
        let margins = pageIn.margins.map { Insets(top: $0.top, left: $0.left, right: $0.right, bottom: $0.bottom) } ?? Insets(top: 48, left: 36, right: 36, bottom: 48)
        let page = PageSpec(widthPt: pageIn.widthPt, heightPt: pageIn.heightPt, margins: margins)
        let scene = LayoutEngine.layout(page: page)
        let apiScene = toAPI(scene)
        return .ok(.init(body: .json(apiScene)))
    }

    // Map core Scene -> generated Components.Schemas.Scene
    private func toAPI(_ scene: LayoutKit.Scene) -> Components.Schemas.Scene {
        // For now, return only page metadata; commands can be mapped later.
        let apiPage = Components.Schemas.PageSpec(
            widthPt: scene.page.widthPt,
            heightPt: scene.page.heightPt,
            margins: .init(top: scene.page.margins.top, left: scene.page.margins.left, right: scene.page.margins.right, bottom: scene.page.margins.bottom)
        )
        return .init(page: apiPage, commands: [])
    }
}
