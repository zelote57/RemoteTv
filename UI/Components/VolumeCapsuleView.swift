// VolumeCapsuleView.swift — Cápsula vertical de volumen con frames matemáticos garantizados
// Elimina problemas de layout de AutoLayout en iOS 12 que causaban botones de altura 0

import UIKit

class VolumeCapsuleView: UIView {

    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    private let plusButton = UIButton(type: .custom)
    private let minusButton = UIButton(type: .custom)
    private let divider = UIView()

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
        clipsToBounds = true

        // Botón + (Subir volumen)
        plusButton.setTitle("+", for: .normal)
        plusButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 26, weight: .semibold)
        plusButton.addTarget(self, action: #selector(didTapPlus), for: .touchUpInside)
        addPressFeedback(to: plusButton)
        addSubview(plusButton)

        // Divisor central
        divider.backgroundColor = Theme.Colors.divider
        addSubview(divider)

        // Botón − (Bajar volumen)
        minusButton.setTitle("−", for: .normal)
        minusButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        minusButton.addTarget(self, action: #selector(didTapMinus), for: .touchUpInside)
        addPressFeedback(to: minusButton)
        addSubview(minusButton)

        Theme.Shadows.applyButtonShadow(to: layer)
    }

    private func addPressFeedback(to button: UIButton) {
        button.addTarget(self, action: #selector(btnDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(btnUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func btnDown(_ sender: UIButton) {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.10) {
            sender.backgroundColor = Theme.Colors.surfacePressed
        }
    }

    @objc private func btnUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.20) {
            sender.backgroundColor = .clear
        }
    }

    @objc private func didTapPlus() {
        onVolumeUp?()
    }

    @objc private func didTapMinus() {
        onVolumeDown?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        layer.cornerRadius = w / 2.0 // Forma de píldora vertical perfecta

        let halfH = h / 2.0
        plusButton.frame = CGRect(x: 0, y: 0, width: w, height: halfH)
        divider.frame = CGRect(x: 16, y: halfH - 0.5, width: w - 32, height: 1.0)
        minusButton.frame = CGRect(x: 0, y: halfH, width: w, height: halfH)
    }
}
