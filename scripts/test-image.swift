// Test helper: puts a generated 1440×900 PNG on the clipboard, like a ⌘⇧4 screenshot does.
// Run: swift scripts/test-image.swift
import AppKit

let width = 1440, height = 900
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGradient(starting: .systemIndigo, ending: .systemTeal)!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 30)
let text = "ClipStack test image \(Date())" as NSString
text.draw(at: NSPoint(x: 80, y: 420), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 56), .foregroundColor: NSColor.white])
NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.setData(png, forType: .png)
print("Put a \(width)×\(height) PNG (\(png.count) bytes) on the clipboard.")
