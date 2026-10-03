#!/usr/bin/env swift

// Adds a restrained title above complete-app native captures. The app image
// is fitted in full: no controls are cropped, invented, or moved.
import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
  fputs("Usage: swift compose_titled_app_pages.swift <source-manifest.json> <output-directory>\n", stderr)
  exit(64)
}

let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard
  let data = try? Data(contentsOf: manifestURL),
  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
  let screenshots = json["screenshots"] as? [[String: Any]]
else {
  fputs("Could not read screenshot manifest.\n", stderr)
  exit(66)
}

let scale: CGFloat = 2
func pt(_ pixels: CGFloat) -> CGFloat { pixels / scale }
func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
  NSRect(x: pt(x), y: pt(y), width: pt(width), height: pt(height))
}

let canvasSize = NSSize(width: pt(1320), height: pt(2868))
let top = NSColor(calibratedRed: 0.180, green: 0.102, blue: 0.200, alpha: 1)
let bottom = NSColor(calibratedRed: 0.090, green: 0.051, blue: 0.110, alpha: 1)
let cream = NSColor(calibratedRed: 0.969, green: 0.933, blue: 0.902, alpha: 1)
let ember = NSColor(calibratedRed: 0.894, green: 0.341, blue: 0.239, alpha: 1)

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

for entry in screenshots {
  guard
    let file = entry["file"] as? String,
    let headline = entry["caption"] as? String,
    let source = NSImage(contentsOf: manifestURL.deletingLastPathComponent().appendingPathComponent(file))
  else {
    fputs("Missing file or caption in screenshot manifest.\n", stderr)
    exit(66)
  }

  let canvas = NSImage(size: canvasSize)
  canvas.lockFocusFlipped(true)
  guard let context = NSGraphicsContext.current else {
    fputs("Could not create graphics context.\n", stderr)
    exit(70)
  }
  context.imageInterpolation = .high
  NSGradient(starting: top, ending: bottom)!.draw(
    in: NSRect(origin: .zero, size: canvasSize),
    angle: -90
  )

  let kickerStyle = NSMutableParagraphStyle()
  kickerStyle.alignment = .left
  ("LETTER WITHIN" as NSString).draw(
    in: rect(76, 60, 1168, 42),
    withAttributes: [
      .font: NSFont.systemFont(ofSize: pt(25), weight: .semibold),
      .foregroundColor: cream.withAlphaComponent(0.72),
      .kern: pt(6.2),
      .paragraphStyle: kickerStyle,
    ]
  )
  ember.setFill()
  NSBezierPath(roundedRect: rect(76, 124, 86, 8), xRadius: pt(4), yRadius: pt(4)).fill()

  let headlineStyle = NSMutableParagraphStyle()
  headlineStyle.alignment = .left
  headlineStyle.lineBreakMode = .byWordWrapping
  headlineStyle.minimumLineHeight = pt(93)
  headlineStyle.maximumLineHeight = pt(93)
  let font = NSFont(name: "NewYork-Medium", size: pt(81))
    ?? NSFont(name: "New York", size: pt(81))
    ?? NSFont(name: "Georgia-Bold", size: pt(78))
    ?? NSFont.systemFont(ofSize: pt(78), weight: .bold)
  (headline as NSString).draw(
    in: rect(76, 167, 1168, 238),
    withAttributes: [
      .font: font,
      .foregroundColor: cream,
      .kern: pt(-1.3),
      .paragraphStyle: headlineStyle,
    ]
  )

  // The entire 1320 × 2868 native capture fits below the title. Side margins
  // are the app's same dark visual world, with no drawn device or overlay.
  let imageHeight: CGFloat = 2434
  let imageWidth = imageHeight * 1320 / 2868
  let imageX = (1320 - imageWidth) / 2
  source.draw(
    in: rect(imageX, 434, imageWidth, imageHeight),
    from: NSRect(origin: .zero, size: source.size),
    operation: .copy,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
  )
  canvas.unlockFocus()

  guard
    let tiff = canvas.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    bitmap.pixelsWide == 1320,
    bitmap.pixelsHigh == 2868,
    let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.97])
  else {
    fputs("Could not encode 1320 × 2868 JPEG.\n", stderr)
    exit(70)
  }
  let destination = outputURL.appendingPathComponent(URL(fileURLWithPath: file).lastPathComponent)
  try jpeg.write(to: destination, options: .atomic)
  print("Wrote \(destination.path)")
}
