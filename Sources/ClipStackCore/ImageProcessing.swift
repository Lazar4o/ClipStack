import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct NormalizedImage: Sendable {
    public let png: Data
    public let width: Int
    public let height: Int
}

/// ImageIO-only helpers (no NSImage decoding of full-size images).
public enum ImageProcessing {
    /// Returns PNG bytes (the original bytes when already PNG) plus the pixel size.
    /// Non-PNG input is re-encoded with `CGImageDestinationAddImageFromSource`, which keeps DPI and
    /// color profile, so Retina screenshots paste at the right size.
    public static func normalizeToPNG(_ data: Data, uti: String) -> NormalizedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let index = largestImageIndex(source)
        let (width, height) = pixelSize(source, index: index)
        guard width > 0, height > 0 else { return nil }

        if uti == UTType.png.identifier && index == 0 {
            return NormalizedImage(png: data, width: width, height: height)
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImageFromSource(destination, source, index, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return NormalizedImage(png: output as Data, width: width, height: height)
    }

    /// Small PNG for list rows; never decode full images for the UI.
    public static func thumbnailPNG(fromPNG png: Data, maxPixel: Int = 720) -> Data? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    public static func pixelSize(ofImageData data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let size = pixelSize(source, index: 0)
        return size.0 > 0 ? (size.0, size.1) : nil
    }

    // MARK: - Private

    /// TIFFs from the pasteboard can hold several representations (1x + 2x); take the biggest.
    static func largestImageIndex(_ source: CGImageSource) -> Int {
        var best = 0
        var bestArea = -1
        for index in 0..<CGImageSourceGetCount(source) {
            let (w, h) = pixelSize(source, index: index)
            if w * h > bestArea {
                bestArea = w * h
                best = index
            }
        }
        return best
    }

    static func pixelSize(_ source: CGImageSource, index: Int) -> (Int, Int) {
        let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let width = (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (props?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        return (width, height)
    }
}
