LayoutKit Coordinates & Conventions

Summary
- Page coordinates: points (pt, 72 dpi), y-up internally. Painters that require y-down (CoreGraphics) flip at the canvas.
- Staff coordinates: staff spaces (SP). Engraving rules and glyph sizes use SP. Convert to pt only at paint/layout boundaries.
- Boxes and anchors: every printable object has a Box (x,y,width,height) in page coordinates; anchors define baseline, midline, stem tips, etc.
- Determinism: the same inputs must produce the same Scene; painters are stateless.

Units
- pt: physical page, margins, absolute layout
- SP: engraving logic (staff spacing, glyph sizes, beam thickness/gap)
- em: text fallback (non-SMuFL)

Transforms
- Scene commands carry affine transforms (a,b,c,d,e,f). All geometry is emitted in y-up page coordinates.
- Painters apply transforms and snap strokes to half pixels at target resolution for crisp lines.

Snapping
- Staff lines and stems snap to half pixels (lineWidth=1 -> y = n + 0.5) to avoid antialias blur.
- Accidental and glyph anchoring uses SMuFL metrics; path bounds may adjust to center baselines.

Page Topology
- Page -> Systems -> Measures -> Voices -> Events
- System frames are explicit boxes in page coords; measure boxes are optional but recommended for hit testing.

Scene
- Display list of Commands: Save/Restore, Transform, DrawPath, DrawTextRun.
- Portable: the same Scene can be rendered by SDLKit, CoreGraphics, Cairo, SVG, or PDF backends.

