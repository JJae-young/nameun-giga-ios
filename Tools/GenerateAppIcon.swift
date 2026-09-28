import AppKit
import CoreGraphics
import Foundation

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Unable to create bitmap context")
}

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(red: 69 / 255, green: 184 / 255, blue: 245 / 255, alpha: 1).cgColor,
        NSColor(red: 47 / 255, green: 128 / 255, blue: 237 / 255, alpha: 1).cgColor,
        NSColor(red: 23 / 255, green: 105 / 255, blue: 224 / 255, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 0.58, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 120, y: 940),
    end: CGPoint(x: 900, y: 80),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

context.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
context.fillEllipse(in: CGRect(x: 52, y: 202, width: 860, height: 860))

context.setFillColor(NSColor.white.cgColor)
let bars = [
    CGRect(x: 238, y: 254, width: 132, height: 188),
    CGRect(x: 446, y: 254, width: 132, height: 348),
    CGRect(x: 654, y: 254, width: 132, height: 516)
]
for bar in bars {
    context.addPath(CGPath(roundedRect: bar, cornerWidth: 50, cornerHeight: 50, transform: nil))
    context.fillPath()
}

guard let image = context.makeImage() else {
    fatalError("Unable to create icon image")
}
let bitmap = NSBitmapImageRep(cgImage: image)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.png")
try png.write(to: output, options: .atomic)
