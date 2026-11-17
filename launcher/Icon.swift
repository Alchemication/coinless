import AppKit

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.08, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 15, y: 15, width: 994, height: 994), xRadius: 210, yRadius: 210).fill()
let accent = NSColor(calibratedRed: 0.72, green: 0.92, blue: 0.47, alpha: 1)
accent.withAlphaComponent(0.12).setFill()
NSBezierPath(roundedRect: NSRect(x: 95, y: 190, width: 834, height: 570), xRadius: 100, yRadius: 100).fill()
accent.setStroke()
let outline = NSBezierPath(roundedRect: NSRect(x: 115, y: 210, width: 794, height: 530), xRadius: 85, yRadius: 85)
outline.lineWidth = 12; outline.stroke()
let stem = NSBezierPath(); stem.move(to: NSPoint(x: 345, y: 365)); stem.line(to: NSPoint(x: 345, y: 560)); stem.lineWidth = 35; stem.stroke()
accent.setFill()
NSBezierPath(ovalIn: NSRect(x: 280, y: 520, width: 130, height: 130)).fill()
NSBezierPath(roundedRect: NSRect(x: 240, y: 330, width: 210, height: 40), xRadius: 20, yRadius: 20).fill()
for point in [NSPoint(x: 575, y: 535), NSPoint(x: 705, y: 565), NSPoint(x: 575, y: 390), NSPoint(x: 705, y: 420)] {
    NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 85, height: 85)).fill()
}
image.unlockFocus()
func lengthData(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}
var chunks = Data()
for (size, type) in [(128, "ic07"), (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    chunks.append(Data(type.utf8)); chunks.append(lengthData(png.count + 8)); chunks.append(png)
}
var output = Data("icns".utf8)
output.append(lengthData(chunks.count + 8)); output.append(chunks)
try output.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
