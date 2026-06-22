#!/usr/bin/env swift
//
// RenderAppIcon.swift — renders the Aware iOS app icon into the asset catalog.
//
// Aware's mark is the family **glossy 3D disc** — a domed white-glass button
// with a crisp shield glyph knocked out of its face so the luminous field shows
// through. Same material as Clink's keycap, Cling's pin disc, Cloe's brain disc,
// Rev's rev-counter, Cluster's control puck and Clack's push-to-talk — but on a
// calm teal field. Teal is Aware's colour: a reassuring, safety-green field
// rather than an alarming red. The shield reads "protected".
//
// Run via `make icon`.
//
// iOS specifics, both required:
//   • the background is drawn full-bleed and fully opaque (no squircle clip,
//     no rim stroke) — iOS applies its own icon mask, and App Store icons must
//     not have an alpha channel.
//   • a single 1024px PNG per appearance (light/dark/tinted).
//
// A 4th "translucent" mode renders the disc as frosted clear glass on a
// transparent field (wallpaper shows through) → Resources/icon-translucent-*.png.
//
import AppKit

let size = 1024.0
let outDir = "Resources/Assets.xcassets/AppIcon.appiconset"
let galleryPath = "Resources/icon-512.png"

let arg = CommandLine.arguments.dropFirst().first ?? "all"
let modes = (arg == "all") ? ["light", "dark", "tinted", "translucent"] : [arg]

func renderPNG(size: CGFloat, mode: String) -> Data? {
    let px = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    draw(in: ctx.cgContext, size: size, mode: mode)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// Draw `symbol` (point size `box`, centred at `center`) flat-filled with `fill`
// straight onto the current context. Drawn as a tinted NSImage so the glyph
// keeps Core Graphics' native antialiasing. With `knockout: true` the glyph is
// punched out of what's already drawn (`.destinationOut`) so the field/wallpaper
// shows through the shape.
func drawSymbol(_ name: String, box: CGFloat, center: CGPoint, fill: NSColor, knockout: Bool = false) {
    let cfg = NSImage.SymbolConfiguration(pointSize: box, weight: .medium)
    guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return }
    let s = sym.size
    let tinted = NSImage(size: s)
    tinted.lockFocus()
    fill.set()
    let r = NSRect(origin: .zero, size: s)
    sym.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(at: NSPoint(x: center.x - s.width / 2, y: center.y - s.height / 2),
                from: NSRect(origin: .zero, size: s),
                operation: knockout ? .destinationOut : .sourceOver, fraction: 1.0)
}

// Draw `symbol` filled with a luminous diagonal gradient (`fillStops`, first
// colour at the top) plus a glossy top sheen, so the glyph pops off the glass
// like a molded, back-lit legend (cf. Clink's indigo "C"). The fill and sheen
// are composited `.sourceAtop` inside an offscreen the shape of the symbol, so
// both stay clipped to the glyph with no stray edges.
func drawSymbolGradient(_ name: String, box: CGFloat, center: CGPoint,
                        fillStops: [(NSColor, CGFloat)], sheenTopAlpha: CGFloat) {
    let cfg = NSImage.SymbolConfiguration(pointSize: box, weight: .medium)
    guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return }
    let s = sym.size
    let img = NSImage(size: s)
    img.lockFocus()
    let r = NSRect(origin: .zero, size: s)
    NSColor.black.set()
    sym.draw(in: r)                                   // establish the shape + alpha
    NSGraphicsContext.current?.compositingOperation = .sourceAtop
    NSGradient(colors: fillStops.map { $0.0 },
               atLocations: fillStops.map { $0.1 }, colorSpace: .sRGB)!
        .draw(in: r, angle: -90)                       // first stop at top, descending
    NSGradient(colors: [NSColor(white: 1, alpha: sheenTopAlpha), NSColor(white: 1, alpha: 0)],
               atLocations: [0, 0.5], colorSpace: .sRGB)!
        .draw(in: r, angle: -90)                       // glossy upper sheen, fades by mid
    img.unlockFocus()
    img.draw(at: NSPoint(x: center.x - s.width / 2, y: center.y - s.height / 2),
             from: r, operation: .sourceOver, fraction: 1.0)
}

func draw(in cg: CGContext, size: CGFloat, mode: String) {
    let isDark   = (mode == "dark")
    let isTinted = (mode == "tinted")
    let isGlass  = (mode == "translucent")   // frosted clear puck, wallpaper shows through
    let space = CGColorSpaceCreateDeviceRGB()
    func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
    func grad(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
        CGGradient(colorsSpace: space, colors: stops.map { $0.0 } as CFArray,
                   locations: stops.map { $0.1 })!
    }

    // ── The calm teal field — painted as the background, and again through the
    //    glyph cutout so the mark reveals the field. Bright aqua top-left, deep
    //    teal mid, near-black bottom-right. ──────────────────────────────────
    func drawField() {
        let bg = isDark
            ? grad([(rgb(0.05, 0.30, 0.30), 0), (rgb(0.03, 0.20, 0.21), 0.52), (rgb(0.01, 0.05, 0.06), 1)])
            : grad([(rgb(0.36, 0.92, 0.86), 0), (rgb(0.06, 0.62, 0.60), 0.52), (rgb(0.01, 0.10, 0.12), 1)])
        cg.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0),
                              options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        // Soft aqua key-light bloom overhead.
        let bloomC = CGPoint(x: size * 0.5, y: size * 0.66)
        cg.drawRadialGradient(grad([(rgb(0.80, 1.00, 0.96, isDark ? 0.18 : 0.38), 0),
                                    (rgb(0.70, 1.00, 0.95, 0.00), 1)]),
                              startCenter: bloomC, startRadius: 0,
                              endCenter: bloomC, endRadius: size * 0.55, options: [])
        // Cool cyan accent low-right for depth.
        let warmC = CGPoint(x: size * 0.90, y: size * 0.12)
        cg.drawRadialGradient(grad([(rgb(0.10, 0.80, 0.78, isDark ? 0.18 : 0.32), 0),
                                    (rgb(0.10, 0.80, 0.78, 0.00), 1)]),
                              startCenter: warmC, startRadius: 0,
                              endCenter: warmC, endRadius: size * 0.5, options: [])
    }
    if !isTinted && !isGlass { drawField() }

    // ── 3D disc — an extruded white-glass puck (visible side wall = depth) ─────
    let discR = size * 0.365                         // vertical radius
    let discRX = discR * 1.07                        // a touch wider — the 3D wall reads tall
    let depth = size * 0.060                         // extrusion height (the wall)
    let discC = CGPoint(x: size * 0.5, y: size * 0.5 + depth * 0.55 + size * 0.005)
    let topRect = CGRect(x: discC.x - discRX, y: discC.y - discR, width: discRX * 2, height: discR * 2)
    func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    // Contact shadow grounding the puck on the field (skip tinted/glass).
    if !isTinted && !isGlass {
        cg.saveGState()
        cg.translateBy(x: 0, y: -depth)
        cg.setShadow(offset: CGSize(width: 0, height: -size * 0.022), blur: size * 0.06,
                     color: rgb(0.01, 0.05, 0.06, 0.55))
        cg.setFillColor(rgb(0, 0, 0, 1))
        cg.fillEllipse(in: topRect)
        cg.restoreGState()
    }

    // Glass mode composites the whole puck as one translucent group so the
    // wallpaper reads through it; the glyph is drawn after at full strength.
    if isGlass { cg.setAlpha(0.58); cg.beginTransparencyLayer(auxiliaryInfo: nil) }

    // Extruded side wall: fill the disc at descending offsets, darkening to the
    // base, so the puck reads as a solid object with thickness.
    let steps = Int(depth)
    for i in stride(from: steps, through: 0, by: -1) {
        let t = Double(i) / Double(steps)            // 1 at base, 0 at top edge
        let r, g, b: Double
        if isTinted {
            r = lerp(0.62, 0.30, t); g = lerp(0.62, 0.30, t); b = lerp(0.62, 0.30, t)
        } else if isDark {
            r = lerp(0.16, 0.07, t); g = lerp(0.32, 0.16, t); b = lerp(0.31, 0.16, t)
        } else {
            r = lerp(0.58, 0.34, t); g = lerp(0.80, 0.52, t); b = lerp(0.78, 0.52, t)
        }
        cg.saveGState()
        cg.translateBy(x: 0, y: -CGFloat(i))
        cg.setFillColor(rgb(r, g, b, 1))
        cg.fillEllipse(in: topRect)
        cg.restoreGState()
    }

    // Top face: white glass — a soft vertical gradient, a dished edge, and a
    // broad upper sheen. Warmed a touch toward aqua so it sits on the teal field.
    cg.saveGState()
    cg.addEllipse(in: topRect); cg.clip()
    let face: CGGradient
    if isTinted {
        face = grad([(rgb(0.98, 0.98, 0.98), 0), (rgb(0.90, 0.90, 0.90), 0.55), (rgb(0.80, 0.80, 0.80), 1)])
    } else if isDark {
        face = grad([(rgb(0.27, 0.33, 0.33), 0), (rgb(0.20, 0.25, 0.25), 0.55), (rgb(0.13, 0.17, 0.17), 1)])
    } else {
        face = grad([(rgb(1.00, 1.00, 1.00), 0), (rgb(0.94, 0.99, 0.98), 0.55), (rgb(0.84, 0.96, 0.94), 1)])
    }
    cg.drawLinearGradient(face, start: CGPoint(x: discC.x, y: topRect.maxY),
                          end: CGPoint(x: discC.x, y: topRect.minY), options: [])
    // Dished edge: darken toward the rim so the centre reads gently scooped.
    let dish: CGGradient
    if isTinted {
        dish = grad([(rgb(0.55, 0.55, 0.55, 0.0), 0), (rgb(0.55, 0.55, 0.55, 0.0), 0.6), (rgb(0.45, 0.45, 0.45, 0.35), 1)])
    } else if isDark {
        dish = grad([(rgb(0.06, 0.10, 0.10, 0.0), 0), (rgb(0.06, 0.10, 0.10, 0.0), 0.6), (rgb(0.03, 0.06, 0.06, 0.5), 1)])
    } else {
        dish = grad([(rgb(0.74, 0.90, 0.88, 0.0), 0), (rgb(0.74, 0.90, 0.88, 0.0), 0.6), (rgb(0.56, 0.78, 0.74, 0.45), 1)])
    }
    cg.drawRadialGradient(dish, startCenter: discC, startRadius: 0,
                          endCenter: discC, endRadius: discRX, options: [])
    // Broad soft sheen across the upper face.
    cg.saveGState()
    cg.translateBy(x: discC.x, y: discC.y + discR * 0.34); cg.scaleBy(x: 1.0, y: 0.5)
    cg.drawRadialGradient(grad([(rgb(1, 1, 1, isDark ? 0.32 : 0.7), 0), (rgb(1, 1, 1, 0.0), 1)]),
                          startCenter: .zero, startRadius: 0, endCenter: .zero,
                          endRadius: discR * 0.66, options: [])
    cg.restoreGState()
    cg.restoreGState()

    // Crisp lit rim along the top edge of the top face.
    cg.saveGState()
    cg.addEllipse(in: topRect.insetBy(dx: size * 0.004, dy: size * 0.004))
    cg.setLineWidth(size * 0.012)
    cg.replacePathWithStrokedPath(); cg.clip()
    cg.drawLinearGradient(grad([(rgb(1, 1, 1, 0.95), 0), (rgb(1, 1, 1, 0.0), 1)]),
                          start: CGPoint(x: discC.x, y: topRect.maxY),
                          end: CGPoint(x: discC.x, y: discC.y), options: [])
    cg.restoreGState()

    if isGlass { cg.endTransparencyLayer(); cg.setAlpha(1.0) }

    // ── Checkmark-shield glyph on the disc face. Glass → a clean transparent
    //    knockout so the wallpaper shows through; light → teal, reading like the
    //    field shows through; dark → white so it stands off the graphite face;
    //    tinted → mid-grey so iOS maps its tint over it. ─────────────────────
    let glyphBox = discR * 1.34
    if isGlass {
        drawSymbol("shield.fill", box: glyphBox, center: discC, fill: .black, knockout: true)
    } else if isTinted {
        // Flat mid-grey so iOS maps its single tint over it cleanly.
        drawSymbol("shield.fill", box: glyphBox, center: discC, fill: NSColor(white: 0.40, alpha: 1))
    } else {
        // Engraved drop-shadow so the shield reads as inset into the glass.
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -size * 0.004), blur: size * 0.012,
                     color: isDark ? rgb(0, 0, 0, 0.55) : rgb(0.01, 0.16, 0.18, 0.45))
        let base: NSColor = isDark ? NSColor(white: 0.06, alpha: 1)
                                   : NSColor(srgbRed: 0.02, green: 0.30, blue: 0.32, alpha: 1)
        drawSymbol("shield.fill", box: glyphBox, center: discC, fill: base)
        cg.restoreGState()

        // Vivid saturated aqua→teal→deep-teal diagonal + glossy sheen, so the
        // field's colour pops luminously through the mark.
        let fillStops: [(NSColor, CGFloat)] = isDark
            ? [(NSColor(srgbRed: 0.50, green: 1.00, blue: 0.93, alpha: 1), 0),
               (NSColor(srgbRed: 0.16, green: 0.82, blue: 0.78, alpha: 1), 0.5),
               (NSColor(srgbRed: 0.05, green: 0.50, blue: 0.53, alpha: 1), 1)]
            : [(NSColor(srgbRed: 0.22, green: 0.94, blue: 0.86, alpha: 1), 0),   // bright aqua
               (NSColor(srgbRed: 0.04, green: 0.72, blue: 0.68, alpha: 1), 0.5), // teal
               (NSColor(srgbRed: 0.01, green: 0.44, blue: 0.47, alpha: 1), 1)]   // deep teal
        drawSymbolGradient("shield.fill", box: glyphBox, center: discC,
                           fillStops: fillStops, sheenTopAlpha: isDark ? 0.18 : 0.30)
    }
}

// Appiconset modes write into the asset catalog; "translucent" is a standalone
// glass asset under Resources (no valid legacy-appiconset appearance for it).
let fileFor = ["light":       "\(outDir)/icon-1024.png",
               "dark":        "\(outDir)/icon-1024-dark.png",
               "tinted":      "\(outDir)/icon-1024-tinted.png",
               "translucent": "Resources/icon-translucent-1024.png"]
for mode in modes {
    guard let path = fileFor[mode] else { fatalError("unknown mode: \(mode)") }
    guard let png = renderPNG(size: size, mode: mode) else { fatalError("render failed: \(mode)") }
    try! png.write(to: URL(fileURLWithPath: path))
    print("→ \(path)")
    if mode == "light", let png512 = renderPNG(size: 512, mode: "light") {
        try! png512.write(to: URL(fileURLWithPath: galleryPath))
        print("→ \(galleryPath)")
    }
    if mode == "translucent", let png512 = renderPNG(size: 512, mode: "translucent") {
        try! png512.write(to: URL(fileURLWithPath: "Resources/icon-translucent-512.png"))
        print("→ Resources/icon-translucent-512.png")
    }
}
