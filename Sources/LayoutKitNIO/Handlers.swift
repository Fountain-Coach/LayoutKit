import Foundation
import OpenAPIRuntime
import HTTPTypes
import LayoutKit
import LayoutKitAPI
import LayoutKitBridge

// Default API handlers delegating to the in‑process LayoutEngine.
public struct DefaultHandlers: APIProtocol, Sendable {
    public init() {}

    // GET /health
    public func getHealth(_ input: Operations.getHealth.Input) async throws -> Operations.getHealth.Output {
        _ = input
        return .ok
    }

    // GET /version
    public func getVersion(_ input: Operations.getVersion.Input) async throws -> Operations.getVersion.Output {
        _ = input
        let payload = Operations.getVersion.Output.Ok.Body.jsonPayload(api: "layoutkit-0.1.0", scene: "scene-v1")
        return .ok(.init(body: .json(payload)))
    }

    // POST /layout/page
    public func layoutPage(
        _ input: Operations.layoutPage.Input
    ) async throws -> Operations.layoutPage.Output {
        let pageIn: Components.Schemas.PageSpec
        switch input.body { case .json(let v): pageIn = v }
        let margins = pageIn.margins.map { Insets(top: $0.top, left: $0.left, right: $0.right, bottom: $0.bottom) } ?? Insets(top: 48, left: 36, right: 36, bottom: 48)
        let page = PageSpec(widthPt: pageIn.widthPt, heightPt: pageIn.heightPt, margins: margins)
        let scene = LayoutEngine.layout(page: page)
        let apiScene = SceneBridge.toAPI(scene)
        return .ok(.init(body: .json(apiScene)))
    }

    // POST /scene/validate
    public func validateScene(
        _ input: Operations.validateScene.Input
    ) async throws -> Operations.validateScene.Output {
        // For now, accept any Scene shape (schema-validated by generator types)
        _ = input
        return .noContent
    }

    // No additional helpers; conversion handled by SceneBridge
}
