#!/usr/bin/env swift
import AppKit

// Logical canvas, matching create-dmg --window-size in scripts/make-dmg.sh.
let width: CGFloat = 660
let height: CGFloat = 480

// Vertical anchor (distance from the TOP of the window) where create-dmg places
// each icon. Must match the --icon / --app-drop-link y in scripts/make-dmg.sh.
let iconAnchorFromTop: CGFloat = 290
// Finder hangs the icon's label below this anchor, so the visible icon image
// renders above it and the label below it.
let iconImageCenterFromTop = iconAnchorFromTop - 23
let labelBottomFromTop = iconAnchorFromTop + 122

struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    var color: NSColor {
        NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }
}

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: y, width: w, height: h)
}

// NSBitmapImageRep uses a bottom-left origin; we author in top-left coordinates
// and convert here so the layout reads naturally from the top of the window.
func fromTop(_ y: CGFloat) -> CGFloat { height - y }

func drawCenteredText(_ text: String, topY: CGFloat, font: NSFont, color: NSColor, kern: CGFloat = 0) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: kern
    ]
    let lineHeight = font.pointSize * 1.45
    NSString(string: text).draw(in: rect(0, height - topY - lineHeight, width, lineHeight), withAttributes: attributes)
}

func drawDashedRoundedRect(centerX: CGFloat, centerYFromTop: CGFloat, width boxWidth: CGFloat, height boxHeight: CGFloat) {
    let centerY = fromTop(centerYFromTop)
    let path = NSBezierPath(roundedRect: rect(centerX - boxWidth / 2, centerY - boxHeight / 2, boxWidth, boxHeight), xRadius: 24, yRadius: 24)
    path.lineWidth = 1.6
    path.setLineDash([5, 5], count: 2, phase: 0)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    RGBA(red: 195, green: 199, blue: 207, alpha: 1).color.setStroke()
    path.stroke()
}

func drawArrow(yFromTop: CGFloat) {
    let y = fromTop(yFromTop)
    let shaftStart: CGFloat = 282
    let shaftEnd: CGFloat = 376
    let tip: CGFloat = 395
    let arrowColor = RGBA(red: 52, green: 112, blue: 235, alpha: 1).color

    let shaft = NSBezierPath()
    shaft.move(to: CGPoint(x: shaftStart, y: y))
    shaft.line(to: CGPoint(x: shaftEnd, y: y))
    shaft.lineWidth = 4
    shaft.lineCapStyle = .round
    arrowColor.setStroke()
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: CGPoint(x: tip, y: y))
    head.line(to: CGPoint(x: shaftEnd, y: y - 13))
    head.line(to: CGPoint(x: shaftEnd, y: y + 13))
    head.close()
    arrowColor.setFill()
    head.fill()
}

func render(scale: CGFloat, output: String) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width * scale),
        pixelsHigh: Int(height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap")
    }

    bitmap.size = NSSize(width: width, height: height)
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create graphics context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    NSColor.white.setFill()
    rect(0, 0, width, height).fill()

    drawCenteredText(
        "Markdown QuickLook",
        topY: 56,
        font: NSFont.systemFont(ofSize: 30, weight: .semibold),
        color: RGBA(red: 29, green: 29, blue: 31, alpha: 1).color,
        kern: -0.25
    )
    drawCenteredText(
        "Drag the app to Applications to install",
        topY: 108,
        font: NSFont.systemFont(ofSize: 15, weight: .regular),
        color: RGBA(red: 112, green: 112, blue: 117, alpha: 1).color,
        kern: 0.05
    )

    // Each dashed box encloses the icon AND the Finder label beneath it.
    let boxTop = iconImageCenterFromTop - 70
    let boxBottom = labelBottomFromTop + 14
    let boxCenterFromTop = (boxTop + boxBottom) / 2
    let boxHeight = boxBottom - boxTop
    drawDashedRoundedRect(centerX: 165, centerYFromTop: boxCenterFromTop, width: 200, height: boxHeight)
    drawDashedRoundedRect(centerX: 495, centerYFromTop: boxCenterFromTop, width: 200, height: boxHeight)

    drawArrow(yFromTop: iconImageCenterFromTop)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    try png.write(to: URL(fileURLWithPath: output))
}

let directory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
try render(scale: 1, output: directory.appendingPathComponent("dmg-background.png").path)
try render(scale: 2, output: directory.appendingPathComponent("dmg-background@2x.png").path)
