// Renders Veda's app icon (1024px PNG) to the path given as argv[1].
// Original artwork drawn with Core Graphics: a window sliding away into a sunset.
// (No SF Symbols: Apple's license doesn't allow them in app icons.)
import Cocoa

let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a) }

// macOS-style rounded square with a soft shadow
let r = CGRect(x: 100, y: 100, width: S - 200, height: S - 200)
let shape = NSBezierPath(roundedRect: r, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill(); shape.fill()
ctx.restoreGState()
shape.addClip()

// sunset gradient + glossy top
NSGradient(colors: [c(250, 158, 77), c(237, 84, 115), c(115, 66, 179)])!.draw(in: r, angle: -70)
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: CGRect(x: r.minX, y: r.midY, width: r.width, height: r.height / 2), angle: -90)

// trailing ghost windows (motion)
for (dx, a) in [(-120.0, 0.18), (-60.0, 0.38)] {
    NSColor.white.withAlphaComponent(a).setStroke()
    let p = NSBezierPath(roundedRect: CGRect(x: 300 + dx, y: 330, width: 400, height: 330), xRadius: 44, yRadius: 44)
    p.lineWidth = 26; p.stroke()
}

// the window
let w = CGRect(x: 300, y: 330, width: 400, height: 330)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor.white.setFill(); NSBezierPath(roundedRect: w, xRadius: 44, yRadius: 44).fill()
ctx.restoreGState()
for (i, col) in [c(255, 95, 87), c(254, 188, 46), c(40, 200, 64)].enumerated() {
    col.setFill(); NSBezierPath(ovalIn: CGRect(x: w.minX + 40 + CGFloat(i) * 52, y: w.maxY - 72, width: 34, height: 34)).fill()
}

// a little waving line inside
let p = NSBezierPath(); p.lineWidth = 26; p.lineCapStyle = .round
p.move(to: CGPoint(x: w.minX + 90, y: w.minY + 110))
p.curve(to: CGPoint(x: w.maxX - 90, y: w.minY + 110),
        controlPoint1: CGPoint(x: w.minX + 160, y: w.minY + 190), controlPoint2: CGPoint(x: w.maxX - 160, y: w.minY + 30))
c(237, 84, 115).setStroke(); p.stroke()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
