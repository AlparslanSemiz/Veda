// Renders Veda's app icon (1024px PNG) to the path given as argv[1].
import Cocoa

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS-style rounded square with a soft shadow
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill(); path.fill()
ctx.restoreGState()

// sunset gradient: "farewell"
path.addClip()
let g = NSGradient(colors: [
    NSColor(srgbRed: 0.98, green: 0.62, blue: 0.30, alpha: 1),
    NSColor(srgbRed: 0.93, green: 0.33, blue: 0.45, alpha: 1),
    NSColor(srgbRed: 0.45, green: 0.26, blue: 0.70, alpha: 1),
], atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
g.draw(in: rect, angle: -70)

// subtle glossy highlight on the top half
let hl = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
hl.draw(in: CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)

// waving hand
let cfg = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
let sym = NSImage(systemSymbolName: "hand.wave.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
let s = sym.size
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.25).cgColor)
sym.draw(in: CGRect(x: (size - s.width) / 2 + 10, y: (size - s.height) / 2 - 6, width: s.width, height: s.height))

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
