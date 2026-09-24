#!/usr/bin/env swift
// Renders the app icon on the macOS icon grid and writes an .icns file.
// Usage: swift scripts/generate-icon.swift Resources/AppIcon.icns

import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"
let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func withRotation(_ degrees: CGFloat, around center: NSPoint, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: degrees)
    transform.translateX(by: -center.x, yBy: -center.y)
    transform.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func drawIcon() {
    // Base squircle: 824 pt with the standard 100 pt margin that leaves room for the shadow.
    let base = NSRect(x: 100, y: 100, width: 824, height: 824)
    let basePath = roundedRect(base, radius: 186)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 28
    shadow.set()
    color(0x3B6FF5).setFill()
    basePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0x5AA2FF), color(0x4A6CF7), color(0x7A4DF2)])!
        .draw(in: basePath, angle: -60)

    // Soft top highlight gives the glass feel.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.32), NSColor.white.withAlphaComponent(0)])!
        .draw(in: roundedRect(base.insetBy(dx: 6, dy: 6), radius: 180), angle: -90)

    // Back document: translucent, tilted left.
    let back = NSRect(x: 262, y: 262, width: 340, height: 440)
    withRotation(10, around: NSPoint(x: back.midX, y: back.midY)) {
        NSColor.white.withAlphaComponent(0.35).setFill()
        roundedRect(back, radius: 44).fill()
    }

    // Front document with text lines.
    let front = NSRect(x: 372, y: 232, width: 360, height: 470)
    withRotation(-6, around: NSPoint(x: front.midX, y: front.midY)) {
        NSGraphicsContext.saveGraphicsState()
        let cardShadow = NSShadow()
        cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        cardShadow.shadowOffset = NSSize(width: 0, height: -8)
        cardShadow.shadowBlurRadius = 20
        cardShadow.set()
        NSColor.white.withAlphaComponent(0.96).setFill()
        roundedRect(front, radius: 46).fill()
        NSGraphicsContext.restoreGraphicsState()

        color(0x4A6CF7, alpha: 0.22).setFill()
        let widths: [CGFloat] = [250, 210, 250, 170]
        for (index, width) in widths.enumerated() {
            let y = front.maxY - 96 - CGFloat(index) * 62
            roundedRect(NSRect(x: front.minX + 54, y: y, width: width, height: 26), radius: 13).fill()
        }
    }

    // Badge: "this is the default".
    let badge = NSRect(x: 560, y: 196, width: 250, height: 250)
    NSGraphicsContext.saveGraphicsState()
    let badgeShadow = NSShadow()
    badgeShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    badgeShadow.shadowOffset = NSSize(width: 0, height: -8)
    badgeShadow.shadowBlurRadius = 18
    badgeShadow.set()
    color(0x2FB36B).setFill()
    NSBezierPath(ovalIn: badge).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0x4CD97B), color(0x1FA35C)])!.draw(in: NSBezierPath(ovalIn: badge), angle: -90)
    NSColor.white.withAlphaComponent(0.9).setStroke()
    let ring = NSBezierPath(ovalIn: badge.insetBy(dx: 5, dy: 5))
    ring.lineWidth = 6
    ring.stroke()

    let check = NSBezierPath()
    check.move(to: NSPoint(x: badge.minX + 70, y: badge.midY + 2))
    check.line(to: NSPoint(x: badge.minX + 112, y: badge.midY - 42))
    check.line(to: NSPoint(x: badge.maxX - 64, y: badge.midY + 50))
    check.lineWidth = 34
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor.white.setStroke()
    check.stroke()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let scale = CGFloat(size) / canvas
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output)")
