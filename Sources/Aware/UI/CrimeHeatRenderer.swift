import MapKit
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// A rendered crime-density heat field: a colour-mapped raster plus the map rect
/// it covers. Built off the SwiftUI body (in `rebuildHeatImage`) and handed to
/// the map's overlay. `version` bumps every rebuild so the map view knows when to
/// swap — the heavy image stays out of SwiftUI's diffing.
struct HeatImage: Equatable {
    let image: CGImage
    let rect: MKMapRect
    let version: Int

    static func == (l: HeatImage, r: HeatImage) -> Bool { l.version == r.version }
}

/// Builds a smooth crime heatmap raster — the real thing, not a field of discs.
/// Each crime is an additive radial blob; overlapping blobs accumulate into a
/// density buffer, which a transparent→amber→red ramp colourises. MapKit scales
/// the low-res raster up smoothly, so it reads as a continuous heat field.
enum CrimeHeat {
    /// One shared CIContext — creating one per rebuild is wasteful.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// 256×1 colour ramp indexed by density: transparent at the floor, amber
    /// rising to red, alpha climbing with intensity so quiet areas show the map.
    private static let gradient: CGImage = {
        let n = 256
        var px = [UInt8](repeating: 0, count: n * 4)
        for i in 0..<n {
            let (r, g, b, a) = color(Double(i) / Double(n - 1))
            let o = i * 4
            px[o] = r; px[o + 1] = g; px[o + 2] = b; px[o + 3] = a
        }
        let provider = CGDataProvider(data: Data(px) as CFData)!
        return CGImage(width: n, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }()

    /// Amber (low) → red (high), premultiplied; fully transparent below a floor so
    /// areas with no crime don't tint the map.
    private static func color(_ t: Double) -> (UInt8, UInt8, UInt8, UInt8) {
        let tt = min(1, max(0, t))
        if tt < 0.06 { return (0, 0, 0, 0) }
        let s = (tt - 0.06) / 0.94
        let hue = (1 - s) * 0.13          // 0.13 amber → 0 red
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hue: CGFloat(hue), saturation: 0.95, brightness: 1, alpha: 1)
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        let alpha = min(0.78, 0.18 + 0.8 * s)
        return (UInt8(r * alpha * 255), UInt8(g * alpha * 255), UInt8(b * alpha * 255), UInt8(alpha * 255))
    }

    /// Render `points` over `region` (grown a little so a pan reveals already-drawn
    /// heat). Returns nil when there's nothing to draw.
    static func render(points: [CrimePoint], region: MKCoordinateRegion, version: Int) -> HeatImage? {
        guard !points.isEmpty else { return nil }
        let grown = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: min(160, region.span.latitudeDelta * 1.5),
                                   longitudeDelta: min(340, region.span.longitudeDelta * 1.5)))
        let rect = grown.heatMapRect
        guard rect.size.width > 0, rect.size.height > 0 else { return nil }

        // Raster resolution. High enough that the upscale to screen doesn't show
        // texels; a gaussian pass below smooths what's left. Longer side = maxDim.
        let maxDim = 512.0
        let aspect = rect.size.height / rect.size.width
        let W = max(8, Int((aspect <= 1 ? maxDim : maxDim / aspect).rounded()))
        let H = max(8, Int((aspect <= 1 ? maxDim * aspect : maxDim).rounded()))

        // Pass 1 — accumulate density into a grayscale buffer (additive blobs).
        let gray = CGColorSpaceCreateDeviceGray()
        guard let acc = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        acc.setFillColor(gray: 0, alpha: 1)
        acc.fill(CGRect(x: 0, y: 0, width: W, height: H))
        acc.setBlendMode(.plusLighter)

        let sx = Double(W) / rect.size.width
        let sy = Double(H) / rect.size.height
        // Kernel radius ~ 1/16 of the view → neighbouring streets blend to a field.
        let rad = max(4.0, (rect.size.width / 16) * sx)
        let comps: [CGFloat] = [1, 0.5, 1, 0]   // (gray,alpha) centre → edge
        guard let blob = CGGradient(colorSpace: gray, colorComponents: comps,
                                    locations: [0, 1], count: 2) else { return nil }

        for p in points {
            let mp = MKMapPoint(p.coordinate)
            let cx = (mp.x - rect.origin.x) * sx
            let cy = Double(H) - (mp.y - rect.origin.y) * sy   // flip: north up
            if cx < -rad || cy < -rad || cx > Double(W) + rad || cy > Double(H) + rad { continue }
            acc.drawRadialGradient(blob, startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                                   endCenter: CGPoint(x: cx, y: cy), endRadius: rad, options: [])
        }
        guard let intensity = acc.makeImage() else { return nil }

        // Pass 2 — colourise the density buffer through the ramp.
        let filter = CIFilter.colorMap()
        filter.inputImage = CIImage(cgImage: intensity)
        filter.gradientImage = CIImage(cgImage: gradient)
        guard let mapped = filter.outputImage else { return nil }

        // Pass 3 — soften so the field reads smooth, not blocky. Clamp first so
        // the blur doesn't pull in a transparent halo at the edges, then crop
        // back to the raster bounds.
        let smoothed = mapped.clampedToExtent().applyingGaussianBlur(sigma: Double(W) / 90)
        let crop = CGRect(x: 0, y: 0, width: W, height: H)
        guard let cg = ciContext.createCGImage(smoothed, from: crop) else { return nil }
        return HeatImage(image: cg, rect: rect, version: version)
    }
}

extension MKCoordinateRegion {
    /// The map rect this region covers (north-west corner has the smaller y).
    var heatMapRect: MKMapRect {
        let nw = MKMapPoint(CLLocationCoordinate2D(latitude: center.latitude + span.latitudeDelta / 2,
                                                   longitude: center.longitude - span.longitudeDelta / 2))
        let se = MKMapPoint(CLLocationCoordinate2D(latitude: center.latitude - span.latitudeDelta / 2,
                                                   longitude: center.longitude + span.longitudeDelta / 2))
        return MKMapRect(x: min(nw.x, se.x), y: min(nw.y, se.y),
                         width: abs(se.x - nw.x), height: abs(se.y - nw.y))
    }
}

/// The crime heatmap as a single map overlay (cheap to pan vs. hundreds of discs).
final class CrimeHeatOverlay: NSObject, MKOverlay {
    let image: CGImage
    let boundingMapRect: MKMapRect
    var coordinate: CLLocationCoordinate2D {
        MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }
    init(_ heat: HeatImage) {
        self.image = heat.image
        self.boundingMapRect = heat.rect
        super.init()
    }
}

/// Draws the heat raster into the overlay's rect, flipped to match MapKit's
/// coordinate space.
final class CrimeHeatRenderer: MKOverlayRenderer {
    private let image: CGImage
    init(heatOverlay: CrimeHeatOverlay) {
        self.image = heatOverlay.image
        super.init(overlay: heatOverlay)
    }
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        let r = rect(for: overlay.boundingMapRect)
        ctx.interpolationQuality = .high
        ctx.saveGState()
        ctx.translateBy(x: r.minX, y: r.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: r.width, height: r.height))
        ctx.restoreGState()
    }
}
