// Generates Resources/AppIcon.icns. Run from the project root: swift scripts/make-icon.swift
// Draws on Apple's macOS icon grid (824 px rounded rect on a 1024 px canvas) and builds
// AppIcon.iconset with the exact file names iconutil expects.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)          // draw in 1024-point space at any pixel size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // Body with soft shadow
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor(calibratedRed: 0.20, green: 0.27, blue: 0.80, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Gradient fill (indigo → teal)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.33, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.62, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.80, blue: 0.74, alpha: 1),
    ])!.draw(in: shape, angle: -60)

    // Stacked "cards" behind the symbol
    for (i, alpha) in [(2, 0.18), (1, 0.30)] {
        let offset = CGFloat(i) * 34
        let card = NSRect(x: 292 + offset, y: 262 + offset, width: 440, height: 520)
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: card, xRadius: 60, yRadius: 60).fill()
    }

    // Clipboard symbol
    let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold)
        .applying(.init(paletteColors: [NSColor(calibratedRed: 0.22, green: 0.36, blue: 0.86, alpha: 1), .white]))
    if let symbol = NSImage(systemSymbolName: "list.clipboard.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        let rect = NSRect(x: 512 - size.width / 2 - 20, y: 470 - size.height / 2 - 20, width: size.width, height: size.height)
        symbol.draw(in: rect)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in entries {
    try renderIcon(pixels: pixels).write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(process.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed (\(process.terminationStatus))")
