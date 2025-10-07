LayoutKit — Spec‑First Page and Scene Layout

Overview
- Spec‑first, deterministic layout engine: “layout as functions”.
- Inputs: `PageSpec`, `SystemSpec` and symbol/text runs in SP (staff‑space) units.
- Output: portable vector display list (`Scene`) in page coordinates (points, y‑up).
- Painting: A `Canvas` abstraction renders `Scene` to backends (SDLKit, CoreGraphics, SVG, PDF).

Clean Mapping
- LayoutKit (this package)
  - What: OpenAPI 3.1 for PageSpec, Scene, Commands; Swift types; in‑process engine.
  - Role: Deterministic page/scene generator; returns a portable `Scene`.
  - Where: In‑process Swift (generated types optional); can also be hosted as a local service.
- SDLKit (separate, we own)
  - What: Cross‑platform canvas/runtime.
  - Role: Primary `Canvas` backend for LayoutKit (2D first‑class). On Linux/Windows uses SDL + FreeType + HarfBuzz; on macOS maps to CoreGraphics/CoreText.
  - Delivers: On‑screen vector preview, PNG/SVG/PDF rasterization.
- ScoreKit
  - What: Music model + RulesKit engraving policies (beaming, slurs, spacing).
  - Role: Translator to LayoutKit requests. Produces `PageSpec`/`SystemSpec` + symbol runs (SMuFL) in SP; LayoutKit builds `Scene` in page points.
- Teatro
  - Host/integrator with plugin registry, CLI, GUI preview, and snapshot culture.
  - Renderer plugins call LayoutKit to obtain `Scene`, then paint via chosen backend (SVG/PDF emitters, SDLKitCanvas, CoreGraphicsCanvas).

Data Flow (Teatro in the middle)
1. ScoreKit model (+ RulesKit) → `PageSpec`/`SystemSpec` (+ symbols in SP).
2. Teatro renderer plugin → calls LayoutKit to get a `Scene` (vector display list).
3. `Scene` → painted by selected `Canvas` (SDLKitCanvas for UI; SVG/PDF emitters for artifacts; CoreGraphicsCanvas for macOS previews).
4. CLI/GUI/Apps → built on Teatro keep a consistent UX; Compare app can show ScoreKit→LayoutKit vs Lily side‑by‑side.

Conventions
- Page coords: points (pt, 72 dpi), y‑up internally. Flip only in painters that require y‑down.
- Staff coords: SP (staff‑space units). ScoreKit/RulesKit talk SP; LayoutKit converts to absolute page coords.
- Pixel snapping: `Scene` carries stroke widths; painters snap to half‑pixels for crisp lines.
- Determinism: `Scene` JSON is canonical; SVG snapshots are CI‑diffable.

Immediate Steps (scaffold)
- Spec: `openapi/layoutkit.yaml` (done). See `COORDINATES.md` for pt vs SP and transforms.
- In‑process engine: `LayoutEngine.layout(page:)` builds a minimal `Scene` (page/margins and groups).
- Canvas: `SVGCanvas` renders a `Scene` to SVG for snapshots; SDLKit/CoreGraphics backends live in their respective repos.
- Teatro integration: Add a renderer plugin that depends on LayoutKit and emits SVG/PDF/PNG using the chosen Canvas.

Getting Started
- SwiftPM
  - Add to `Package.swift` dependencies: `.package(url: "https://github.com/Fountain-Coach/LayoutKit.git", branch: "main")`
  - Target dependency: `.product(name: "LayoutKit", package: "LayoutKit")`
- Sample
  ```swift
  import LayoutKit

  let page = PageSpec(widthPt: 595.0, heightPt: 842.0) // A4
  let scene = LayoutEngine.layout(page: page)

  let canvas = SVGCanvas(width: page.widthPt, height: page.heightPt)
  SceneRenderer.render(scene, on: canvas)
  let svg = canvas.svgString()
  ```

OpenAPI Generator (Apple)
- Codegen target: `LayoutKitAPI` uses Apple's Swift OpenAPI Generator plugin.
- Document: `openapi/layoutkit.yaml` (canonical). Symlinked as `Sources/LayoutKitAPI/openapi.yaml` for the plugin.
- Config: `Sources/LayoutKitAPI/openapi-generator-config.yaml` generates public `types`, `client`, and `server` stubs.
- CI: `.github/workflows/ci.yml` builds and tests; generation runs on build and is not checked in.

Client usage (URLSession transport)
```swift
import LayoutKitAPI
import OpenAPIURLSession

let transport = URLSessionTransport()
let client = Client(serverURL: URL(string: "http://127.0.0.1:8080")!, transport: transport)

// Example call (matches /layout/page in the spec)
let page = Components.Schemas.PageSpec(widthPt: 595, heightPt: 842, margins: .init(top: 48, left: 36, right: 36, bottom: 48))
let response = try await client.post_layout_page(.init(body: .json(page)))
let scene: Components.Schemas.Scene
switch response {
case .ok(let ok): scene = try ok.ok.body.json
default: throw SomeError()
}
```

Server stubs
- `LayoutKitAPI` also includes generated server interfaces. Adopt a server transport (e.g., Vapor) in a separate package and implement the handlers by delegating to `LayoutEngine`.

Versioning
- Track breaking changes in `openapi/layoutkit.yaml` via the `info.version` field.
- Keep spec and engine in lockstep; CI ensures generator compatibility.

Server Executable (NIO)
- Run the local NIO server executable for manual testing:
  - Build: `swift build -c release -Xswiftc -parse-as-library`
  - Run: `swift run LayoutKitNIOServer` (env: `LAYOUTKIT_HOST`, `LAYOUTKIT_PORT` to override)
  - Test the endpoint:
    ```bash
    curl -sS -X POST http://127.0.0.1:8080/layout/page \
      -H 'accept: application/json' \
      -H 'content-type: application/json' \
      -d '{"widthPt":595,"heightPt":842,"margins":{"top":48,"left":36,"right":36,"bottom":48}}' | jq
    ```

SVG Snapshots
- Use `SVGCanvas` to render a `Scene` for snapshot tests / previews:
  ```swift
  let page = PageSpec(widthPt: 200, heightPt: 100)
  let scene = LayoutEngine.layout(page: page)
  let canvas = SVGCanvas(width: page.widthPt, height: page.heightPt)
  SceneRenderer.render(scene, on: canvas)
  let svg = canvas.svgString()
  ```

SDLKit Canvas
- Target: `LayoutKitSDLCanvas` provides a concrete `Canvas` backed by SDLKit.
- Usage (preview; no-op draw methods until wired):
  ```swift
  import LayoutKit
  import LayoutKitSDLCanvas

  let canvas = SDLKitCanvas()
  SceneRenderer.render(scene, on: canvas)
  ```
- Enabling full SDLKit integration:
  - This target conditionally imports `SDLKit` with `#if canImport(SDLKit)`.
  - To wire real drawing, add `SDLKit` to your workspace/package and implement the TODOs in `SDLKitCanvas` (tessellation, glyphs, images, clip).
  - We will upstream a complete mapping once SDLKit’s 2D primitives are finalized.

Badges
- CI: LayoutKit builds + OpenAPI codegen on every push (see Actions).
- Docs: OpenAPI HTML published via GitHub Pages (workflow `Publish API Docs`).

Teatro Wiring (outline)
- Add a new renderer plugin (e.g., `TeatroLayoutKitRenderer`) that:
  - Accepts a high‑level request (e.g., `renderScorePage`).
  - Calls ScoreKit to produce `PageSpec`/symbol runs.
  - Calls LayoutKit to build a `Scene`.
  - Paints via SDLKitCanvas (for UI) or emits SVG/PDF.
- During local development, depend on LayoutKit via a path dependency; switch to the Git URL when the repo is public.

Pure SwiftNIO Server
- Target `LayoutKitNIO` provides a minimal `ServerTransport` implementation using `swift-nio` (HTTP/1.1).
- Usage (server):
  ```swift
  import LayoutKitAPI
  import LayoutKitNIO

  let transport = NIOHTTPServerTransport(host: "127.0.0.1", port: 8080)
  let handlers = DefaultHandlers() // delegates to LayoutEngine
  try handlers.registerHandlers(on: transport)
  try await transport.start()
  ```
- The transport supports OpenAPI path templates (e.g., `/file/{name}.zip`) and passes path params in `ServerRequestMetadata`.

Repository Layout
- `Sources/LayoutKit/` — Swift types, engine, and minimal SVG canvas.
- `openapi/layoutkit.yaml` — OpenAPI 3.1 for the API (future generator/service optional).
- `COORDINATES.md` — Units, transforms, snapping.
- `Tests/` — Determinism and smoke tests.

License
- Copyright (c) Fountain‑Coach.
