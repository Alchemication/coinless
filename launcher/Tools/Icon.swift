import AppKit

// Coinless app icon: an arcade coin slot behind a glowing "no" sign, on a dark CRT-style tile.
// Usage: make-icon <output.icns>

let canvas: CGFloat = 1024
let center = NSPoint(x: canvas / 2, y: canvas / 2)
let accent = NSColor(calibratedRed: 0.72, green: 0.92, blue: 0.47, alpha: 1)

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

// Tile with a soft vertical gradient and faint scanlines.
let tile = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 205, yRadius: 205)
NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.115, blue: 0.14, alpha: 1),
           ending: NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.05, alpha: 1))?.draw(in: tile, angle: -90)
NSGraphicsContext.saveGraphicsState()
tile.addClip()
NSColor.black.withAlphaComponent(0.18).setFill()
for y in stride(from: 50.0, to: 974.0, by: 12.0) { NSRect(x: 50, y: y, width: 924, height: 5).fill() }
NSGraphicsContext.restoreGraphicsState()

// Coin door plate.
let plate = NSBezierPath(roundedRect: NSRect(x: center.x - 150, y: center.y - 235, width: 300, height: 470), xRadius: 54, yRadius: 54)
NSGradient(starting: NSColor(calibratedWhite: 0.30, alpha: 1), ending: NSColor(calibratedWhite: 0.14, alpha: 1))?.draw(in: plate, angle: -90)
NSColor(calibratedWhite: 0.42, alpha: 1).setStroke()
plate.lineWidth = 6
plate.stroke()

// The slot itself, with a lit rim.
let slot = NSBezierPath(roundedRect: NSRect(x: center.x - 30, y: center.y - 150, width: 60, height: 300), xRadius: 30, yRadius: 30)
NSColor(calibratedWhite: 0.02, alpha: 1).setFill()
slot.fill()
NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.25, alpha: 0.9).setStroke()
slot.lineWidth = 7
slot.stroke()

// "No" sign: ring plus diagonal bar, with a glow.
NSGraphicsContext.saveGraphicsState()
let glow = NSShadow()
glow.shadowColor = accent.withAlphaComponent(0.75)
glow.shadowBlurRadius = 40
glow.set()
accent.setStroke()
let radius: CGFloat = 340
let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
ring.lineWidth = 64
ring.stroke()
let offset = radius * 0.7071
let bar = NSBezierPath()
bar.move(to: NSPoint(x: center.x - offset, y: center.y + offset))
bar.line(to: NSPoint(x: center.x + offset, y: center.y - offset))
bar.lineWidth = 64
bar.stroke()
NSGraphicsContext.restoreGraphicsState()

image.unlockFocus()

func lengthData(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

var chunks = Data()
for (size, type) in [(32, "ic11"), (64, "ic12"), (128, "ic07"), (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                                        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    chunks.append(Data(type.utf8))
    chunks.append(lengthData(png.count + 8))
    chunks.append(png)
}
var output = Data("icns".utf8)
output.append(lengthData(chunks.count + 8))
output.append(chunks)
try output.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
