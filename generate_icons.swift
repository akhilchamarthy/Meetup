#!/usr/bin/env swift
//
//  generate_icons.swift
//  Run from the project root:  swift generate_icons.swift
//  Requires macOS 12+ (Monterey or later).
//
import AppKit
import Foundation

// ── Output directory ────────────────────────────────────────────────────────
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let iconsetURL = scriptDir
    .appendingPathComponent("Meetup MessagesExtension")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("iMessage App Icon.stickersiconset")

// ── Icon specs ───────────────────────────────────────────────────────────────
// (filename, point-width, point-height, scale)  →  pixel size = pt × scale
struct Spec {
    let filename: String
    let ptW: Int; let ptH: Int; let scale: Int
    var px: Int { ptW * scale }
    var py: Int { ptH * scale }
}

let specs: [Spec] = [
    Spec(filename: "icon-iphone-29@2x.png",       ptW:   29, ptH:   29, scale: 2),
    Spec(filename: "icon-iphone-29@3x.png",       ptW:   29, ptH:   29, scale: 3),
    Spec(filename: "icon-iphone-60x45@2x.png",    ptW:   60, ptH:   45, scale: 2),
    Spec(filename: "icon-iphone-60x45@3x.png",    ptW:   60, ptH:   45, scale: 3),
    Spec(filename: "icon-ipad-29@2x.png",         ptW:   29, ptH:   29, scale: 2),
    Spec(filename: "icon-ipad-67x50@2x.png",      ptW:   67, ptH:   50, scale: 2),
    Spec(filename: "icon-ipad-74x55@2x.png",      ptW:   74, ptH:   55, scale: 2),
    Spec(filename: "icon-marketing-1024.png",     ptW: 1024, ptH: 1024, scale: 1),
    Spec(filename: "icon-universal-27x20@2x.png", ptW:   27, ptH:   20, scale: 2),
    Spec(filename: "icon-universal-27x20@3x.png", ptW:   27, ptH:   20, scale: 3),
    Spec(filename: "icon-universal-32x24@2x.png", ptW:   32, ptH:   24, scale: 2),
    Spec(filename: "icon-universal-32x24@3x.png", ptW:   32, ptH:   24, scale: 3),
    Spec(filename: "icon-marketing-1024x768.png", ptW: 1024, ptH:  768, scale: 1),
]

// ── Renderer ─────────────────────────────────────────────────────────────────
/// Draws the Meetup logo into the current graphics context.
/// Coordinate system must be UIKit-style: origin top-left, Y increases downward.
/// For square canvases the logo fills the frame.
/// For rectangular canvases a circle is drawn centered inside the frame.
func drawMeetupLogo(in frame: CGRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    let pw = frame.width, ph = frame.height
    let s  = min(pw, ph)   // use shorter dimension as the unit
    let cx = pw / 2, cy = ph / 2

    // ── Palette ──────────────────────────────────────────────────────────────
    let blue     = NSColor(red: 0.22, green: 0.58, blue: 1.00, alpha: 1)
    let deepBlue = NSColor(red: 0.10, green: 0.32, blue: 0.82, alpha: 1)
    let sky      = NSColor(red: 0.58, green: 0.80, blue: 1.00, alpha: 1)
    let dotGray  = NSColor(red: 0.76, green: 0.84, blue: 0.94, alpha: 1)
    let white    = NSColor.white

    func linearGrad(in rect: CGRect, from: NSColor, to: NSColor) {
        let space  = CGColorSpaceCreateDeviceRGB()
        let colors = [from.cgColor, to.cgColor] as CFArray
        guard let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
        ctx.drawLinearGradient(g,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end:   CGPoint(x: rect.maxX, y: rect.maxY),
            options: [])
    }

    // ── Clip to circle for rectangular canvases ───────────────────────────────
    let isRect = pw != ph
    let circleDiam = s * (isRect ? 0.90 : 1.0)
    let circleRect = CGRect(x: cx - circleDiam/2, y: cy - circleDiam/2,
                            width: circleDiam, height: circleDiam)

    if isRect {
        // Light background outside the circle
        NSColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 1).setFill()
        NSBezierPath(rect: frame).fill()

        // Clip everything that follows to the circle
        ctx.saveGState()
        NSBezierPath(ovalIn: circleRect).addClip()
    }

    // ── Blue gradient background ──────────────────────────────────────────────
    let bgRect = isRect ? circleRect : frame
    linearGrad(in: bgRect, from: blue, to: deepBlue)

    // ── Card geometry ─────────────────────────────────────────────────────────
    let cardW  = s * 0.60
    let cardH  = s * 0.64
    let radius = s * 0.10
    // Logo is anchored to the circle area
    let logoCX = isRect ? cx : cx
    let logoCY = isRect ? cy : cy
    let cardCY = logoCY - s * 0.04

    // ── Back page (offset + slight rotation) ──────────────────────────────────
    let backRect = CGRect(
        x: logoCX - cardW/2 + s*0.06,
        y: cardCY - cardH/2 - s*0.03,
        width: cardW, height: cardH
    )
    ctx.saveGState()
    ctx.translateBy(x: backRect.midX, y: backRect.midY)
    ctx.rotate(by: .pi / 13)
    ctx.translateBy(x: -backRect.midX, y: -backRect.midY)
    white.withAlphaComponent(0.28).setFill()
    NSBezierPath(roundedRect: backRect, xRadius: radius, yRadius: radius).fill()
    ctx.restoreGState()

    // ── Front card ────────────────────────────────────────────────────────────
    let cardRect = CGRect(
        x: logoCX - cardW/2 - s*0.02,
        y: cardCY - cardH/2,
        width: cardW, height: cardH
    )
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)

    // Shadow + white fill
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: s * 0.025),
                  blur: s * 0.06,
                  color: NSColor.black.withAlphaComponent(0.22).cgColor)
    white.setFill()
    cardPath.fill()
    ctx.restoreGState()

    white.setFill()
    cardPath.fill()

    // ── Header stripe ─────────────────────────────────────────────────────────
    let headerH    = cardH * 0.26
    let headerRect = CGRect(x: cardRect.minX, y: cardRect.minY, width: cardW, height: headerH)
    ctx.saveGState()
    cardPath.addClip()                       // rounded card clips the header corners
    linearGrad(in: headerRect, from: blue, to: deepBlue)
    ctx.restoreGState()

    // Binding rings
    let ringY = cardRect.minY + headerH * 0.5
    let ringR  = s * 0.030
    for dx in [-cardW * 0.22, cardW * 0.22] {
        white.withAlphaComponent(0.80).setFill()
        NSBezierPath(ovalIn: CGRect(
            x: cardRect.midX + dx - ringR, y: ringY - ringR,
            width: ringR * 2, height: ringR * 2
        )).fill()
    }

    // ── Calendar grid — 5 × 3 dots ───────────────────────────────────────────
    let gridL  = cardRect.minX + cardW * 0.13
    let gridR  = cardRect.maxX - cardW * 0.13
    let gridT  = cardRect.minY + headerH + cardH * 0.09
    let gridB  = cardRect.maxY - cardH * 0.34
    let dotR   = s * 0.024
    let cols = 5, rows = 3
    let cStep = (gridR - gridL) / CGFloat(cols - 1)
    let rStep = (gridB - gridT) / CGFloat(rows - 1)

    for row in 0..<rows {
        for col in 0..<cols {
            let dx = gridL + CGFloat(col) * cStep
            let dy = gridT + CGFloat(row) * rStep

            if row == 1 && col == 2 {           // highlighted "chosen" date
                let bigR = dotR * 1.55
                blue.setFill()
                NSBezierPath(ovalIn: CGRect(x: dx-bigR, y: dy-bigR,
                                           width: bigR*2, height: bigR*2)).fill()
                white.setFill()
                NSBezierPath(ovalIn: CGRect(x: dx-dotR, y: dy-dotR,
                                           width: dotR*2, height: dotR*2)).fill()
            } else {
                dotGray.setFill()
                NSBezierPath(ovalIn: CGRect(x: dx-dotR, y: dy-dotR,
                                           width: dotR*2, height: dotR*2)).fill()
            }
        }
    }

    // ── People avatars ────────────────────────────────────────────────────────
    let avD    = s * 0.178
    let avBord = s * 0.014
    let avY    = cardRect.maxY - avD * 0.52
    let avStep = avD * 0.70
    let avFills: [NSColor] = [sky, white, sky.withAlphaComponent(0.75)]

    for i in stride(from: 2, through: 0, by: -1) {
        let ax     = cardRect.midX + CGFloat(i - 1) * avStep
        let avRect = CGRect(x: ax - avD/2, y: avY, width: avD, height: avD)

        // White border ring
        white.setFill()
        NSBezierPath(ovalIn: avRect.insetBy(dx: -avBord, dy: -avBord)).fill()

        // Avatar fill
        avFills[i].setFill()
        NSBezierPath(ovalIn: avRect).fill()

        // Head
        let hR = avD * 0.19
        let hY = avRect.minY + avD * 0.32
        blue.withAlphaComponent(0.50).setFill()
        NSBezierPath(ovalIn: CGRect(x: ax-hR, y: hY-hR, width: hR*2, height: hR*2)).fill()

        // Shoulders: circle offset below, clipped to avatar
        ctx.saveGState()
        NSBezierPath(ovalIn: avRect).addClip()
        let shR = avD * 0.33
        let shY = avRect.maxY + avD * 0.05 - shR   // top of shoulder circle
        blue.withAlphaComponent(0.50).setFill()
        NSBezierPath(ovalIn: CGRect(x: ax-shR, y: shY, width: shR*2, height: shR*2)).fill()
        ctx.restoreGState()
    }

    if isRect { ctx.restoreGState() }  // pop circle clip
}

// ── Render & save one icon ────────────────────────────────────────────────────
func renderAndSave(spec: Spec) throws {
    let pw = CGFloat(spec.px), ph = CGFloat(spec.py)

    // NSImage with flipped: true  →  Y=0 at top, same convention as UIKit
    let img = NSImage(size: NSSize(width: pw, height: ph), flipped: true) { rect in
        drawMeetupLogo(in: rect)
        return true
    }

    guard let tiff = img.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:])
    else { throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG conversion failed for \(spec.filename)"]) }

    let dest = iconsetURL.appendingPathComponent(spec.filename)
    try png.write(to: dest)
    print("✓  \(spec.filename)  (\(spec.px)×\(spec.py)px)")
}

// ── Update Contents.json ─────────────────────────────────────────────────────
let contentsJSON = """
{
  "images" : [
    { "filename" : "icon-iphone-29@2x.png",       "idiom" : "iphone",         "scale" : "2x", "size" : "29x29"     },
    { "filename" : "icon-iphone-29@3x.png",       "idiom" : "iphone",         "scale" : "3x", "size" : "29x29"     },
    { "filename" : "icon-iphone-60x45@2x.png",    "idiom" : "iphone",         "scale" : "2x", "size" : "60x45"     },
    { "filename" : "icon-iphone-60x45@3x.png",    "idiom" : "iphone",         "scale" : "3x", "size" : "60x45"     },
    { "filename" : "icon-ipad-29@2x.png",         "idiom" : "ipad",           "scale" : "2x", "size" : "29x29"     },
    { "filename" : "icon-ipad-67x50@2x.png",      "idiom" : "ipad",           "scale" : "2x", "size" : "67x50"     },
    { "filename" : "icon-ipad-74x55@2x.png",      "idiom" : "ipad",           "scale" : "2x", "size" : "74x55"     },
    { "filename" : "icon-marketing-1024.png",     "idiom" : "ios-marketing",  "scale" : "1x", "size" : "1024x1024" },
    { "filename" : "icon-universal-27x20@2x.png", "idiom" : "universal",      "platform" : "ios", "scale" : "2x", "size" : "27x20" },
    { "filename" : "icon-universal-27x20@3x.png", "idiom" : "universal",      "platform" : "ios", "scale" : "3x", "size" : "27x20" },
    { "filename" : "icon-universal-32x24@2x.png", "idiom" : "universal",      "platform" : "ios", "scale" : "2x", "size" : "32x24" },
    { "filename" : "icon-universal-32x24@3x.png", "idiom" : "universal",      "platform" : "ios", "scale" : "3x", "size" : "32x24" },
    { "filename" : "icon-marketing-1024x768.png", "idiom" : "ios-marketing",  "platform" : "ios", "scale" : "1x", "size" : "1024x768" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

// ── Main ──────────────────────────────────────────────────────────────────────
print("Generating Meetup iMessage icons…\n")

do {
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

    for spec in specs {
        try renderAndSave(spec: spec)
    }

    let jsonURL = iconsetURL.appendingPathComponent("Contents.json")
    try contentsJSON.write(to: jsonURL, atomically: true, encoding: .utf8)
    print("\n✓  Contents.json updated")
    print("\nDone! Build the project in Xcode to pick up the new icons.")

} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
