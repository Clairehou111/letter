#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 7 else {
  fputs(
    "Usage: swift compose_app_store_screenshot_v2.swift <source.png> <output.jpg> <daylight|care> <headline> <crop-top-px> <crop-height-px>\n",
    stderr
  )
  exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let theme = CommandLine.arguments[3]
let headline = CommandLine.arguments[4].replacingOccurrences(of: "\\n", with: "\n")
let cropTop = CGFloat(Double(CommandLine.arguments[5]) ?? 0)
let requestedCropHeight = CGFloat(Double(CommandLine.arguments[6]) ?? 0)

guard ["daylight", "care"].contains(theme) else {
  fputs("Theme must be daylight or care.\n", stderr)
  exit(64)
}

guard let source = NSImage(contentsOf: sourceURL) else {
  fputs("Could not read source image at \(sourceURL.path).\n", stderr)
  exit(66)
}

let scale: CGFloat = 2
func pt(_ value: CGFloat) -> CGFloat { value / scale }
func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
  NSRect(x: pt(x), y: pt(y), width: pt(width), height: pt(height))
}

let canvas = NSImage(size: NSSize(width: pt(1290), height: pt(2796)))
canvas.lockFocusFlipped(true)

guard let context = NSGraphicsContext.current else {
  fputs("Could not create drawing context.\n", stderr)
  exit(70)
}
context.imageInterpolation = .high

// Extend the app's real visual worlds instead of introducing a separate
// campaign palette around the native UI.
let appCanvas = NSColor(calibratedRed: 0.984, green: 0.969, blue: 0.953, alpha: 1) // #FBF7F3
let appInk = NSColor(calibratedRed: 0.165, green: 0.086, blue: 0.149, alpha: 1) // #2A1626
let appEmber = NSColor(calibratedRed: 0.894, green: 0.341, blue: 0.239, alpha: 1) // #E4573D
let careTop = NSColor(calibratedRed: 0.180, green: 0.102, blue: 0.200, alpha: 1) // #2E1A33
let careBottom = NSColor(calibratedRed: 0.090, green: 0.051, blue: 0.110, alpha: 1) // #170D1C
let careInk = NSColor(calibratedRed: 0.969, green: 0.933, blue: 0.902, alpha: 1) // #F7EEE6
let isCare = theme == "care"
let background = isCare ? careBottom : appCanvas
let ink = isCare ? careInk : appInk

if isCare {
  let gradient = NSGradient(starting: careTop, ending: careBottom)!
  gradient.draw(in: NSRect(origin: .zero, size: canvas.size), angle: -90)
} else {
  background.setFill()
  NSBezierPath(rect: NSRect(origin: .zero, size: canvas.size)).fill()
}

let kickerStyle = NSMutableParagraphStyle()
kickerStyle.alignment = .left
let kickerAttributes: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: pt(25), weight: .semibold),
  .foregroundColor: ink.withAlphaComponent(0.68),
  .kern: pt(6.2),
  .paragraphStyle: kickerStyle,
]
("LETTER WITHIN" as NSString).draw(
  in: rect(76, 68, 1138, 48),
  withAttributes: kickerAttributes
)

appEmber.setFill()
NSBezierPath(
  roundedRect: rect(76, 137, 88, 9),
  xRadius: pt(4.5),
  yRadius: pt(4.5)
).fill()

let headlineStyle = NSMutableParagraphStyle()
headlineStyle.alignment = .left
headlineStyle.lineBreakMode = .byWordWrapping
headlineStyle.minimumLineHeight = pt(94)
headlineStyle.maximumLineHeight = pt(94)

let headlineFont = NSFont(name: "NewYork-Medium", size: pt(82))
  ?? NSFont(name: "New York", size: pt(82))
  ?? NSFont(name: "Georgia-Bold", size: pt(79))
  ?? NSFont.systemFont(ofSize: pt(79), weight: .bold)
let headlineAttributes: [NSAttributedString.Key: Any] = [
  .font: headlineFont,
  .foregroundColor: ink,
  .kern: pt(-1.5),
  .paragraphStyle: headlineStyle,
]
(headline as NSString).draw(
  in: rect(76, 174, 1138, 250),
  withAttributes: headlineAttributes
)

let viewport = rect(50, 472, 1190, 2324)
let viewportPath = NSBezierPath(
  roundedRect: viewport,
  xRadius: pt(64),
  yRadius: pt(64)
)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = appInk.withAlphaComponent(isCare ? 0.28 : 0.13)
shadow.shadowOffset = NSSize(width: 0, height: pt(-18))
shadow.shadowBlurRadius = pt(42)
shadow.set()
(isCare ? careBottom : NSColor.white).setFill()
viewportPath.fill()
NSGraphicsContext.restoreGraphicsState()

let sourceHeight = source.size.height
let safeTop = min(max(cropTop, 0), max(sourceHeight - 1, 0))
let safeHeight = min(
  requestedCropHeight > 0 ? requestedCropHeight : sourceHeight - safeTop,
  sourceHeight - safeTop
)
let sourceRect = NSRect(x: 0, y: safeTop, width: source.size.width, height: safeHeight)

let sourceAspect = sourceRect.width / sourceRect.height
let viewportAspect = viewport.width / viewport.height
var drawRect = viewport
if isCare {
  // Care's permanent exit is part of the product promise. Fit the complete
  // native screen inside the matching dark world instead of cropping its
  // lower controls to fill the viewport.
  let drawHeight = viewport.height
  let drawWidth = drawHeight * sourceAspect
  drawRect = NSRect(
    x: viewport.midX - drawWidth / 2,
    y: viewport.minY,
    width: drawWidth,
    height: drawHeight
  )
} else if sourceAspect > viewportAspect {
  let drawHeight = viewport.height
  let drawWidth = drawHeight * sourceAspect
  drawRect = NSRect(
    x: viewport.midX - drawWidth / 2,
    y: viewport.minY,
    width: drawWidth,
    height: drawHeight
  )
} else {
  let drawWidth = viewport.width
  let drawHeight = drawWidth / sourceAspect
  drawRect = NSRect(
    x: viewport.minX,
    y: viewport.minY,
    width: drawWidth,
    height: drawHeight
  )
}

NSGraphicsContext.saveGraphicsState()
viewportPath.addClip()
source.draw(
  in: drawRect,
  from: sourceRect,
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
  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.96])
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
