import AppKit

// Extend Nida's existing moon symbol; keep menu-bar template symbols independent.
for development in [false, true] {
    let name = development ? "AppIconDev" : "AppIcon"
    let folder = URL(fileURLWithPath: "Nida/Assets.xcassets/\(name).appiconset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = points * scale
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            let factor = CGFloat(pixels) / 1024
            let transform = NSAffineTransform()
            transform.scale(by: factor)
            transform.concat()
            NSColor(calibratedRed: 0.045, green: 0.09, blue: 0.085, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 206, yRadius: 206).fill()
            NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.88, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 238, y: 225, width: 550, height: 550)).fill()
            NSColor(calibratedRed: 0.045, green: 0.09, blue: 0.085, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 405, y: 362, width: 474, height: 474)).fill()
            NSColor(calibratedRed: 0.49, green: 0.80, blue: 0.67, alpha: 1).setFill()
            let star = NSBezierPath()
            star.move(to: NSPoint(x: 731, y: 696))
            star.line(to: NSPoint(x: 753, y: 755)); star.line(to: NSPoint(x: 812, y: 777))
            star.line(to: NSPoint(x: 753, y: 799)); star.line(to: NSPoint(x: 731, y: 858))
            star.line(to: NSPoint(x: 709, y: 799)); star.line(to: NSPoint(x: 650, y: 777))
            star.line(to: NSPoint(x: 709, y: 755)); star.close(); star.fill()
            if development {
                NSColor(calibratedRed: 0.93, green: 0.65, blue: 0.24, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: 178, y: 118, width: 668, height: 170), xRadius: 55, yRadius: 55).fill()
                let text = "DEV" as NSString
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 118, weight: .bold), .foregroundColor: NSColor.black]
                let size = text.size(withAttributes: attributes)
                text.draw(at: NSPoint(x: (1024-size.width)/2, y: 203-size.height/2), withAttributes: attributes)
            }
            NSGraphicsContext.restoreGraphicsState()
            let file = "icon_\(points)x\(points)@\(scale)x.png"
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(file))
            images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": file])
        }
    }
    let data = try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    try data.write(to: folder.appendingPathComponent("Contents.json"))
}
