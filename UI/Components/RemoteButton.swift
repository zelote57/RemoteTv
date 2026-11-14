// RemoteButton.swift — Circular action button with high-fidelity vector icons
// Fully compliant with Swift 5.0 and iOS 12.0+ (100% vector CoreGraphics rendering, zero square artifacts)

import UIKit

class RemoteButton: UIButton {

    enum IconType {
        case back
        case playPause
        case home
        case none
    }

    private let iconType: IconType

    override var isHighlighted: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

    init(iconType: IconType) {
        self.iconType = iconType
        super.init(frame: .zero)
        setup()
    }

    // Convenience initializer for backwards compatibility
    convenience init(title: String? = nil, style: Int = 0) {
        if title == "←" {
            self.init(iconType: .back)
        } else if title == "⏯" {
            self.init(iconType: .playPause)
        } else if title == "⌂" {
            self.init(iconType: .home)
        } else {
            self.init(iconType: .none)
            if let title = title {
                setTitle(title, for: .normal)
            }
        }
    }

    required init?(coder: NSCoder) {
        self.iconType = .none
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Crucial: keep view background clear so CoreGraphics can draw a pure anti-aliased circle
        backgroundColor = .clear
        clipsToBounds = false
        contentMode = .redraw
        
        applyTheme()
        setupActions()
    }

    func applyTheme() {
        Theme.Shadows.applyButtonShadow(to: layer)
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let circleRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        layer.shadowPath = UIBezierPath(ovalIn: circleRect).cgPath
        Theme.Shadows.applyButtonShadow(to: layer)
    }

    private func setupActions() {
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleTouchDown() {
        HapticManager.playTactileClick()
        
        UIView.animate(withDuration: 0.10, delay: 0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        })
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
        })
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 1. Draw pure circular surface background & border
        let circleRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let circlePath = UIBezierPath(ovalIn: circleRect)

        let surfaceColor = isHighlighted ? Theme.Colors.surfacePressed : Theme.Colors.surface
        ctx.setFillColor(surfaceColor.cgColor)
        circlePath.fill()

        ctx.setStrokeColor(Theme.Colors.border.cgColor)
        ctx.setLineWidth(1.0)
        circlePath.stroke()

        guard iconType != .none else { return }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let iconColor = Theme.Colors.textPrimary

        // 2. Draw Vector Icons
        switch iconType {
        case .back:
            ctx.setStrokeColor(iconColor.cgColor)
            ctx.setLineWidth(2.4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let length: CGFloat = 8.5
            // Horizontal stem
            let line = UIBezierPath()
            line.move(to: CGPoint(x: center.x + length, y: center.y))
            line.addLine(to: CGPoint(x: center.x - length, y: center.y))
            line.stroke()

            // Chevron head
            let head = UIBezierPath()
            head.move(to: CGPoint(x: center.x - length + 6.5, y: center.y - 6.5))
            head.addLine(to: CGPoint(x: center.x - length, y: center.y))
            head.addLine(to: CGPoint(x: center.x - length + 6.5, y: center.y + 6.5))
            head.stroke()

        case .playPause:
            ctx.setFillColor(iconColor.cgColor)

            // Play Triangle
            let playPath = UIBezierPath()
            let playLeft = center.x - 11.0
            let playRight = center.x - 1.5
            let playTop = center.y - 7.5
            let playBottom = center.y + 7.5

            playPath.move(to: CGPoint(x: playLeft, y: playTop))
            playPath.addLine(to: CGPoint(x: playRight, y: center.y))
            playPath.addLine(to: CGPoint(x: playLeft, y: playBottom))
            playPath.close()
            playPath.fill()

            // Pause Dual Bars
            let barWidth: CGFloat = 3.2
            let barHeight: CGFloat = 14.0
            let barTop = center.y - (barHeight / 2.0)
            let barRadius: CGFloat = 1.0

            let bar1Rect = CGRect(x: center.x + 3.0, y: barTop, width: barWidth, height: barHeight)
            let bar1 = UIBezierPath(roundedRect: bar1Rect, cornerRadius: barRadius)
            bar1.fill()

            let bar2Rect = CGRect(x: center.x + 8.5, y: barTop, width: barWidth, height: barHeight)
            let bar2 = UIBezierPath(roundedRect: bar2Rect, cornerRadius: barRadius)
            bar2.fill()

        case .home:
            ctx.setFillColor(iconColor.cgColor)

            // Apple-style Home icon with interior door cutout
            let homePath = UIBezierPath()
            let apex = CGPoint(x: center.x, y: center.y - 9.5)
            let leftEave = CGPoint(x: center.x - 9.5, y: center.y - 2.0)
            let rightEave = CGPoint(x: center.x + 9.5, y: center.y - 2.0)
            let leftBase = CGPoint(x: center.x - 7.5, y: center.y + 8.5)
            let rightBase = CGPoint(x: center.x + 7.5, y: center.y + 8.5)

            homePath.move(to: apex)
            homePath.addLine(to: rightEave)
            homePath.addLine(to: CGPoint(x: center.x + 7.5, y: center.y - 0.5))
            homePath.addLine(to: rightBase)
            homePath.addLine(to: CGPoint(x: center.x + 2.5, y: center.y + 8.5))
            homePath.addLine(to: CGPoint(x: center.x + 2.5, y: center.y + 2.5))
            homePath.addLine(to: CGPoint(x: center.x - 2.5, y: center.y + 2.5))
            homePath.addLine(to: CGPoint(x: center.x - 2.5, y: center.y + 8.5))
            homePath.addLine(to: leftBase)
            homePath.addLine(to: CGPoint(x: center.x - 7.5, y: center.y - 0.5))
            homePath.addLine(to: leftEave)
            homePath.close()
            homePath.fill()

        case .none:
            break
        }
    }
}
