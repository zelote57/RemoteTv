// SharedVectorViews.swift — Reusable vector graphic subviews for sheets and lists
// Fully compliant with Swift 5.0 and iOS 12.0+

import UIKit

// MARK: - CircularCheckmarkView

class CircularCheckmarkView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Green Circle Fill
        let circleRect = rect.insetBy(dx: 1.0, dy: 1.0)
        ctx.setFillColor(Theme.Colors.connected.cgColor)
        ctx.fillEllipse(in: circleRect)

        // Crisp White Checkmark
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2.4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let checkPath = UIBezierPath()
        checkPath.move(to: CGPoint(x: rect.midX - 5.5, y: rect.midY - 0.5))
        checkPath.addLine(to: CGPoint(x: rect.midX - 1.5, y: rect.midY + 3.8))
        checkPath.addLine(to: CGPoint(x: rect.midX + 5.5, y: rect.midY - 4.0))
        checkPath.stroke()
    }
}

// MARK: - ChevronRightView

class ChevronRightView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setStrokeColor(Theme.Colors.textSecondary.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX - 3, y: rect.midY - 5))
        path.addLine(to: CGPoint(x: rect.midX + 2.5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - 3, y: rect.midY + 5))
        path.stroke()
    }
}
