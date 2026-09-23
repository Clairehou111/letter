#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 5 else {
  fputs(
    "Usage: swift compose_app_store_screenshot.swift <source.png> <output.jpg> <light|dark> <headline>\n",
    stderr
  )
  exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let appearance = CommandLine.arguments[3]
let headline = CommandLine.arguments[4].replacingOccurrences(of: "\\n", with: "\n")

guard appearance == "light" || appearance == "dark" else {
  fputs("Appearance must be light or dark.\n", stderr)
  exit(64)
}

guard let source = NSImage(contentsOf: sourceURL) else {
  fputs("Could not read source image at \(sourceURL.path).\n", stderr)
  exit(66)
}

// AppKit renders this script's point canvas at the host's 2× backing scale.
// Keeping all layout values in App Store pixels and converting through `pt`
// produces an encoded 1290 × 2796 bitmap on the supported macOS toolchain.
let backingScale: CGFloat = 2
func pt(_ value: CGFloat) -> CGFloat { value / backingScale }
func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
  NSRect(x: pt(x), y: pt(y), width: pt(width), height: pt(height))
}

let canvasSize = NSSize(width: pt(1290), height: pt(2796))
let canvas = NSImage(size: canvasSize)
canvas.lockFocusFlipped(true)

guard let context = NSGraphicsContext.current else {
  fputs("Could not create drawing context.\n", stderr)
  exit(70)
}

context.imageInterpolation = .high

let dark = appearance == "dark"
let background = dark
  ? NSColor(calibratedRed: 0.105, green: 0.055, blue: 0.125, alpha: 1)
  : NSColor(calibratedRed: 0.985, green: 0.965, blue: 0.945, alpha: 1)
let ink = dark
  ? NSColor(calibratedRed: 0.985, green: 0.950, blue: 0.910, alpha: 1)
  : NSColor(calibratedRed: 0.150, green: 0.070, blue: 0.135, alpha: 1)
let accent = NSColor(calibratedRed: 0.925, green: 0.265, blue: 0.155, alpha: 1)

background.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

let labelStyle = NSMutableParagraphStyle()
labelStyle.alignment = .left
let labelAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: pt(27), weight: .semibold),
  .foregroundColor: dark ? ink.withAlphaComponent(0.72) : ink.withAlphaComponent(0.62),
  .kern: pt(6.5),
  .paragraphStyle: labelStyle,
]
("LETTER WITHIN" as NSString).draw(
  in: rect(104, 72, 1080, 52),
  withAttributes: labelAttributes
)

accent.setFill()
NSBezierPath(
  roundedRect: rect(104, 142, 92, 9),
  xRadius: pt(4.5),
  yRadius: pt(4.5)
).fill()

let headlineStyle = NSMutableParagraphStyle()
headlineStyle.alignment = .left
headlineStyle.lineBreakMode = .byWordWrapping
headlineStyle.minimumLineHeight = pt(101)
headlineStyle.maximumLineHeight = pt(101)

let preferredFont = NSFont(name: "NewYork-Medium", size: pt(88))
  ?? NSFont(name: "New York", size: pt(88))
  ?? NSFont(name: "Georgia-Bold", size: pt(84))
  ?? NSFont.systemFont(ofSize: pt(84), weight: .bold)
let headlineAttributes: [NSAttributedString.Key: Any] = [
  .font: preferredFont,
  .foregroundColor: ink,
  .kern: pt(-1.8),
  .paragraphStyle: headlineStyle,
]
(headline as NSString).draw(
  in: rect(104, 181, 1082, 244),
  withAttributes: headlineAttributes
)

let imageRect = rect(130, 530, 1030, 2239)
let imagePath = NSBezierPath(
  roundedRect: imageRect,
  xRadius: pt(74),
  yRadius: pt(74)
)

NSGraphicsContext.saveGraphicsState()
if !dark {
  let shadow = NSShadow()
  shadow.shadowColor = ink.withAlphaComponent(0.16)
  shadow.shadowOffset = NSSize(width: 0, height: pt(-18))
  shadow.shadowBlurRadius = pt(40)
  shadow.set()
  NSColor.white.setFill()
  imagePath.fill()
}
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
imagePath.addClip()
source.draw(
  in: imageRect,
  from: NSRect(origin: .zero, size: source.size),
  operation: .copy,
  fraction: 1,
  respectFlipped: true,
  hints: [.interpolation: NSImageInterpolation.high]
)
NSGraphicsContext.restoreGraphicsState()

canvas.unlockFocus()

guard
  let tiff = canvas.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
else {
  fputs("Could not encode output image.\n", stderr)
  exit(70)
}

do {
  try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try jpeg.write(to: outputURL, options: .atomic)
} catch {
  fputs("Could not write \(outputURL.path): \(error)\n", stderr)
  exit(73)
}

guard bitmap.pixelsWide == 1290, bitmap.pixelsHigh == 2796 else {
  fputs(
    "Unexpected output size \(bitmap.pixelsWide) × \(bitmap.pixelsHigh); expected 1290 × 2796.\n",
    stderr
  )
  exit(70)
}

print("Wrote \(outputURL.path) (1290 × 2796 JPEG, no alpha)")
