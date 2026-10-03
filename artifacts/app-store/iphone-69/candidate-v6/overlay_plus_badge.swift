import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
  fatalError("usage: swift overlay_plus_badge.swift input.png output.jpg")
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 1320, image.height == 2868,
      let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
  fatalError("expected a 1320 × 2868 source image")
}

let width = CGFloat(image.width)
let height = CGFloat(image.height)
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

// Empty space below Settings, above the Patterns heading. Coordinates are
// measured from the native 1320 × 2868 capture, not a scaled composition.
let badge = CGRect(x: 991, y: height - 341 - 75, width: 262, height: 75)
let path = CGPath(roundedRect: badge, cornerWidth: 37.5, cornerHeight: 37.5, transform: nil)
context.addPath(path)
context.setFillColor(CGColor(red: 0.21, green: 0.14, blue: 0.24, alpha: 1))
context.fillPath()
context.addPath(path)
context.setStrokeColor(CGColor(red: 0.96, green: 0.48, blue: 0.37, alpha: 1))
context.setLineWidth(2.5)
context.strokePath()

let label = NSAttributedString(
  string: "With Plus",
  attributes: [
    .font: NSFont.systemFont(ofSize: 32, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 1, green: 0.96, blue: 0.92, alpha: 1),
  ]
)
let line = CTLineCreateWithAttributedString(label)
let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
context.textPosition = CGPoint(x: badge.midX - lineWidth / 2, y: badge.midY - 11)
CTLineDraw(line, context)

guard let composited = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        output as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      ) else {
  fatalError("could not create output image")
}
CGImageDestinationAddImage(destination, composited, [
  kCGImageDestinationLossyCompressionQuality: 0.98,
] as CFDictionary)
guard CGImageDestinationFinalize(destination) else {
  fatalError("could not write output image")
}
