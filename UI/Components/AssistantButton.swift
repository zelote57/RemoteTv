// AssistantButton.swift — Botón del Asistente de Google con ícono vectorial de 4 colores
// 100% compatible con iOS 12 puro en CoreGraphics

import UIKit

class AssistantButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = Theme.Colors.surface
        layer.borderColor = Theme.Colors.border.cgColor
        layer.borderWidth = 1.0
        contentMode = .redraw
        Theme.Shadows.applyButtonShadow(to: layer)

        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2.0
    }

    @objc private func handleTouchDown() {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.10) {
            self.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            self.backgroundColor = Theme.Colors.surfacePressed
        }
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
            self.backgroundColor = Theme.Colors.surface
        })
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Los 4 puntos icónicos de Google Assistant (Azul, Rojo, Amarillo, Verde)
        // Escalados armónicamente al tamaño del botón
        let scale: CGFloat = rect.width / 72.0

        let dots: [(color: UIColor, x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (UIColor(red: 66/255,  green: 133/255, blue: 244/255, alpha: 1.0), -15.0 * scale,  -1.0 * scale, 5.0 * scale), // Azul
            (UIColor(red: 234/255, green: 67/255,  blue: 53/255,  alpha: 1.0),  -5.0 * scale,   1.0 * scale, 7.5 * scale), // Rojo (principal)
            (UIColor(red: 251/255, green: 188/255, blue: 5/255,   alpha: 1.0),   6.0 * scale,   2.0 * scale, 6.0 * scale), // Amarillo
            (UIColor(red: 52/255,  green: 168/255, blue: 83/255,  alpha: 1.0),  15.5 * scale,  -1.5 * scale, 4.0 * scale)  // Verde
        ]

        for dot in dots {
            ctx.setFillColor(dot.color.cgColor)
            let dotRect = CGRect(
                x: center.x + dot.x - dot.r,
                y: center.y + dot.y - dot.r,
                width: dot.r * 2.0,
                height: dot.r * 2.0
            )
            ctx.fillEllipse(in: dotRect)
        }
    }
}
