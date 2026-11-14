// PowerButton.swift — Circular power button matching Stitch design
// Fully compliant with Swift 5.0 and iOS 12.0+ (100% vector CoreGraphics rendering)

import UIKit

class PowerButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        contentMode = .redraw
        clipsToBounds = false
        
        applyTheme()
        
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    func applyTheme() {
        Theme.Shadows.applyPowerShadow(to: layer)
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        Theme.Shadows.applyPowerShadow(to: layer)
    }

    @objc private func handleTouchDown() {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.10, delay: 0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.alpha = 0.90
        })
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
            self.alpha = 1.0
        })
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let circleRect = rect.insetBy(dx: 2.0, dy: 2.0)
        let isDark = Theme.isDark

        // 1. Draw circular background (Gradient in Dark mode, vibrant Emerald in Light mode)
        if isDark {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [Theme.Colors.powerGradientTop.cgColor, Theme.Colors.powerGradientBottom.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
                ctx.saveGState()
                ctx.addEllipse(in: circleRect)
                ctx.clip()
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: circleRect.midX, y: circleRect.minY),
                    end: CGPoint(x: circleRect.midX, y: circleRect.maxY),
                    options: []
                )
                ctx.restoreGState()
            }
            
            // Subtle top translucent border
            ctx.setStrokeColor(UIColor(white: 1.0, alpha: 0.30).cgColor)
            ctx.setLineWidth(1.0)
            ctx.strokeEllipse(in: circleRect)
        } else {
            ctx.setFillColor(Theme.Colors.power.cgColor)
            ctx.fillEllipse(in: circleRect)
        }

        // 2. Draw Vector Power Symbol (⏻)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.24
        let lineWidth: CGFloat = 2.75

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)

        // Arc (circle open at the top from -38° to 218°)
        let startAngle: CGFloat = -CGFloat.pi * 0.30
        let endAngle: CGFloat = -CGFloat.pi * 0.70
        let arc = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        arc.stroke()

        // Vertical central line
        let line = UIBezierPath()
        line.move(to: CGPoint(x: center.x, y: center.y - radius - 3.5))
        line.addLine(to: CGPoint(x: center.x, y: center.y - 1.0))
        line.lineWidth = lineWidth
        line.lineCapStyle = .round
        line.stroke()
    }
}
