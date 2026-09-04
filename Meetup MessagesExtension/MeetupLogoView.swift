//
//  MeetupLogoView.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

// MARK: - MeetupLogoView

/// Drop-in UIView that draws the Meetup logo at any size.
/// Also exposes a static `image(size:)` method for icon generation.
final class MeetupLogoView: UIView {

    var renderStyle: RenderStyle = .onBlue { didSet { setNeedsDisplay() } }

    enum RenderStyle: Equatable {
        /// Draws the blue gradient background — use this for the app icon.
        case onBlue
        /// Transparent background — use on surfaces that already have colour.
        case standalone
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        MeetupLogoView.render(in: rect, style: renderStyle)
    }

    // MARK: - Static image factory

    /// Returns a UIImage of the logo at the requested size.
    /// Pass `style: .onBlue` for icon assets, `style: .standalone` for in-app.
    static func image(size: CGSize, style: RenderStyle = .onBlue) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            render(in: CGRect(origin: .zero, size: size), style: style)
        }
    }

    // MARK: - Core renderer

    static func render(in rect: CGRect, style: RenderStyle) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let s  = min(rect.width, rect.height)
        let cx = rect.midX
        let cy = rect.midY

        // ── Palette ────────────────────────────────────────────────
        let blue     = UIColor(red: 0.22, green: 0.58, blue: 1.00, alpha: 1)
        let deepBlue = UIColor(red: 0.10, green: 0.32, blue: 0.82, alpha: 1)
        let sky      = UIColor(red: 0.58, green: 0.80, blue: 1.00, alpha: 1)
        let dotGray  = UIColor(red: 0.76, green: 0.84, blue: 0.94, alpha: 1)

        // ── Background (icon mode only) ────────────────────────────
        if style == .onBlue {
            gradient(ctx: ctx, in: rect, from: blue, to: deepBlue)
        }

        // ── Card geometry ──────────────────────────────────────────
        let cardW   = s * 0.60
        let cardH   = s * 0.64
        let radius  = s * 0.10
        let cardCY  = cy - s * 0.04      // shift card upward to leave room for avatars

        // ── Back page (rotated, ghost) ─────────────────────────────
        let backRect = CGRect(
            x: cx - cardW / 2 + s * 0.06,
            y: cardCY - cardH / 2 - s * 0.03,
            width: cardW, height: cardH
        )
        ctx.saveGState()
        ctx.translateBy(x: backRect.midX, y: backRect.midY)
        ctx.rotate(by: .pi / 13)
        ctx.translateBy(x: -backRect.midX, y: -backRect.midY)
        UIColor.white.withAlphaComponent(0.28).setFill()
        UIBezierPath(roundedRect: backRect, cornerRadius: radius).fill()
        ctx.restoreGState()

        // ── Front page ─────────────────────────────────────────────
        let cardRect = CGRect(
            x: cx - cardW / 2 - s * 0.02,
            y: cardCY - cardH / 2,
            width: cardW, height: cardH
        )

        // Shadow pass
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: s * 0.025),
                      blur: s * 0.06,
                      color: UIColor.black.withAlphaComponent(0.22).cgColor)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: cardRect, cornerRadius: radius).fill()
        ctx.restoreGState()

        // White fill (clean, no shadow)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: cardRect, cornerRadius: radius).fill()

        // ── Header stripe ──────────────────────────────────────────
        let headerH    = cardH * 0.26
        let headerRect = CGRect(x: cardRect.minX, y: cardRect.minY,
                                width: cardW, height: headerH)
        ctx.saveGState()
        let headerPath = UIBezierPath(
            roundedRect: headerRect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        headerPath.addClip()
        gradient(ctx: ctx, in: headerRect, from: blue, to: deepBlue)
        ctx.restoreGState()

        // Binding rings on header
        let ringY = cardRect.minY + headerH * 0.5
        let ringR  = s * 0.030
        for dx in [-cardW * 0.22, cardW * 0.22] {
            let rRect = CGRect(
                x: cardRect.midX + dx - ringR,
                y: ringY - ringR,
                width: ringR * 2, height: ringR * 2
            )
            UIColor.white.withAlphaComponent(0.80).setFill()
            UIBezierPath(ovalIn: rRect).fill()
        }

        // ── Calendar grid — 5 × 3 dots ─────────────────────────────
        let gridL = cardRect.minX + cardW * 0.13
        let gridR = cardRect.maxX - cardW * 0.13
        let gridT = cardRect.minY + headerH + cardH * 0.09
        let gridB = cardRect.maxY - cardH * 0.34    // leave room for avatars
        let dotR  = s * 0.024
        let cols = 5; let rows = 3
        let cStep = (gridR - gridL) / CGFloat(cols - 1)
        let rStep = (gridB - gridT) / CGFloat(rows - 1)

        // Highlighted cell = the "agreed" date (centre of grid)
        let hlCol = 2; let hlRow = 1

        for row in 0..<rows {
            for col in 0..<cols {
                let dx = gridL + CGFloat(col) * cStep
                let dy = gridT + CGFloat(row) * rStep

                if row == hlRow && col == hlCol {
                    // Chosen date: larger solid blue ring + white centre
                    let bigR = dotR * 1.55
                    blue.setFill()
                    UIBezierPath(ovalIn: CGRect(x: dx-bigR, y: dy-bigR,
                                               width: bigR*2, height: bigR*2)).fill()
                    UIColor.white.setFill()
                    UIBezierPath(ovalIn: CGRect(x: dx-dotR, y: dy-dotR,
                                               width: dotR*2, height: dotR*2)).fill()
                } else {
                    dotGray.setFill()
                    UIBezierPath(ovalIn: CGRect(x: dx-dotR, y: dy-dotR,
                                               width: dotR*2, height: dotR*2)).fill()
                }
            }
        }

        // ── People avatars ─────────────────────────────────────────
        // Three overlapping circles sit at the bottom of the card,
        // half-overlapping the card's lower edge.
        let avD    = s * 0.178
        let avBord = s * 0.014
        let avY    = cardRect.maxY - avD * 0.52
        let avStep = avD * 0.70
        let avCX   = cardRect.midX

        // Colors: left / centre / right
        let avFills: [UIColor] = [sky, UIColor.white, sky.withAlphaComponent(0.75)]

        // Draw right-to-left so the leftmost is rendered on top
        for i in stride(from: 2, through: 0, by: -1) {
            let ax     = avCX + CGFloat(i - 1) * avStep
            let avRect = CGRect(x: ax - avD/2, y: avY, width: avD, height: avD)

            // White border ring
            UIColor.white.setFill()
            UIBezierPath(ovalIn: avRect.insetBy(dx: -avBord, dy: -avBord)).fill()

            // Avatar fill
            avFills[i].setFill()
            UIBezierPath(ovalIn: avRect).fill()

            // Head circle
            let hR = avD * 0.19
            let hY = avRect.minY + avD * 0.32
            blue.withAlphaComponent(0.48).setFill()
            UIBezierPath(ovalIn: CGRect(x: ax-hR, y: hY-hR, width: hR*2, height: hR*2)).fill()

            // Shoulder arc (clips naturally outside the circle)
            ctx.saveGState()
            UIBezierPath(ovalIn: avRect).addClip()
            let shoulderC = CGPoint(x: ax, y: avRect.maxY + avD * 0.05)
            let shoulderR = avD * 0.33
            let arc = UIBezierPath(arcCenter: shoulderC, radius: shoulderR,
                                   startAngle: .pi, endAngle: 0, clockwise: false)
            arc.close()
            blue.withAlphaComponent(0.48).setFill()
            arc.fill()
            ctx.restoreGState()
        }
    }

    // MARK: - Helpers

    private static func gradient(ctx: CGContext, in rect: CGRect,
                                  from: UIColor, to: UIColor) {
        let space   = CGColorSpaceCreateDeviceRGB()
        let colors  = [from.cgColor, to.cgColor] as CFArray
        guard let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])
        else { return }
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end:   CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }
}
