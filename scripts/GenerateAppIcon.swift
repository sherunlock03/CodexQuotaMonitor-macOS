import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: GenerateAppIcon <iconset-directory> <output.icns>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let icnsURL = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1_024)
]

func point(center: NSPoint, radius: CGFloat, degrees: CGFloat) -> NSPoint {
    let radians = degrees * .pi / 180
    return NSPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
}

func render(size: Int) throws -> Data {
    let side = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }
    context.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: side, height: side)
    let inset = side * 0.035
    let tile = NSBezierPath(
        roundedRect: bounds.insetBy(dx: inset, dy: inset),
        xRadius: side * 0.22,
        yRadius: side * 0.22
    )
    tile.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.075, alpha: 1)
    ])?.draw(in: bounds, angle: -52)

    let glow = NSBezierPath(ovalIn: NSRect(
        x: side * 0.18,
        y: side * 0.25,
        width: side * 0.64,
        height: side * 0.64
    ))
    NSColor(calibratedWhite: 1, alpha: 0.035).setFill()
    glow.fill()

    let center = NSPoint(x: side * 0.5, y: side * 0.42)
    let radius = side * 0.31
    func arc(_ color: NSColor, _ start: CGFloat, _ end: CGFloat) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        path.lineWidth = max(1.5, side * 0.075)
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }
    arc(NSColor(calibratedRed: 1.0, green: 0.27, blue: 0.24, alpha: 1), 200, 139)
    arc(NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.08, alpha: 1), 129, 68)
    arc(NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.36, alpha: 1), 58, -20)

    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: point(center: center, radius: radius * 0.82, degrees: 42))
    needle.lineWidth = max(1.3, side * 0.035)
    needle.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.94).setStroke()
    needle.stroke()

    let hubSize = side * 0.105
    let hub = NSBezierPath(ovalIn: NSRect(
        x: center.x - hubSize / 2,
        y: center.y - hubSize / 2,
        width: hubSize,
        height: hubSize
    ))
    NSColor.white.setFill()
    hub.fill()
    let inner = NSBezierPath(ovalIn: NSRect(
        x: center.x - hubSize * 0.21,
        y: center.y - hubSize * 0.21,
        width: hubSize * 0.42,
        height: hubSize * 0.42
    ))
    NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.25, alpha: 1).setFill()
    inner.fill()

    context.flushGraphics()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

for (name, size) in outputs {
    try render(size: size).write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
}

let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianBytes(_ value: Int) -> Data {
    var integer = UInt32(value).bigEndian
    return withUnsafeBytes(of: &integer) { Data($0) }
}

var icns = Data("icns".utf8)
icns.append(bigEndianBytes(0))
for (type, fileName) in chunks {
    let png = try Data(contentsOf: outputDirectory.appendingPathComponent(fileName))
    icns.append(Data(type.utf8))
    icns.append(bigEndianBytes(png.count + 8))
    icns.append(png)
}
icns.replaceSubrange(4..<8, with: bigEndianBytes(icns.count))
try icns.write(to: icnsURL, options: .atomic)
