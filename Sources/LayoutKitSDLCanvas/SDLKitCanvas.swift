import Foundation
#if canImport(SDLKit)
import SDLKit
#endif
import LayoutKit

// SDLKit-backed Canvas. When SDLKit is available, this type is intended to
// dispatch drawing to an SDL renderer. For now, drawing calls are no-ops until
// SDL primitives are finalized; the presence of this target enables downstream
// integrators (Teatro/SDLKit GUI) to depend on a concrete Canvas type.
public final class SDLKitCanvas: Canvas {
    public struct Transform: Sendable { public var a,b,c,d,e,f: Double }
    private var stack: [Transform] = []

    public init() {}

    public func save() { stack.append(currentTransform()) }
    public func restore() { if !stack.isEmpty { _ = stack.removeLast() } }
    public func transform(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) {
        // Compose top-of-stack with the new transform (affine 2x3)
        // For now only track; mapping to SDL backends comes later.
        let _ = (a,b,c,d,e,f)
    }

    public func drawPath(_ path: Path, style: Style) {
        // TODO: Implement path tessellation + stroke/fill using SDLKit when stabilized.
        _ = (path, style)
    }

    public func drawText(_ run: TextRun) {
        // TODO: Implement glyph atlas + SMuFL via SDLKitTTF/HarfBuzz when stabilized.
        _ = run
    }

    private func currentTransform() -> Transform {
        stack.last ?? Transform(a: 1, b: 0, c: 0, d: 1, e: 0, f: 0)
    }
}

