// PowerButton.swift — Botón de encendido circular con ícono vectorial dibujado en CoreGraphics
// 100% compatible con iOS 12 (sin SF Symbols ni fuentes Unicode faltantes)

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
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleTouchDown() {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.10) {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.alpha = 0.85
        }
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
            self.alpha = 1.0
        })
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 1. Círculo verde de fondo (idéntico a la captura)
        let circleRect = rect.insetBy(dx: 2, dy: 2)
        let greenColor = UIColor(red: 105/255, green: 219/255, blue: 124/255, alpha: 1.0) // Verde vibrante
        ctx.setFillColor(greenColor.cgColor)
        ctx.fillEllipse(in: circleRect)

        // 2. Ícono IEC de Encendido en blanco puro (⏻)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.22
        let lineWidth: CGFloat = 3.2

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)

        // Arco circular abierto arriba (de -40° a 220° aprox)
        let startAngle: CGFloat = -CGFloat.pi * 0.32
        let endAngle: CGFloat = -CGFloat.pi * 0.68
        let arc = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        arc.stroke()

        // Línea vertical superior
        let line = UIBezierPath()
        line.move(to: CGPoint(x: center.x, y: center.y - radius - 3.5))
        line.addLine(to: CGPoint(x: center.x, y: center.y - 1.0))
        line.lineWidth = lineWidth
        line.lineCapStyle = .round
        line.stroke()
    }
}
