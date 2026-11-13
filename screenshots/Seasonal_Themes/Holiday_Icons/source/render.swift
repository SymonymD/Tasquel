import AppKit
// render <in.svg> <out.png> <size> [background hex]: the SVG fitted into a square.
let args = CommandLine.arguments
guard let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else { print("no image", args[1]); exit(1) }
let size = Double(args[3]) ?? 512
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
if args.count > 4, let hex = UInt32(args[4], radix: 16) {
    NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
}
let s = image.size
let scale = min(size / s.width, size / s.height)
let w = s.width * scale, h = s.height * scale
image.draw(in: NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
