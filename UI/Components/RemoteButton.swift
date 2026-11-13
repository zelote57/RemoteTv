import UIKit

class RemoteButton: UIButton {

    enum Style {
        case round
        case pill
        case squareRounded
    }

    private let style: Style

    init(title: String? = nil, icon: UIImage? = nil, style: Style = .round) {
        self.style = style
        super.init(frame: .zero)
        
        setupAppearance()
        if let title = title {
            setTitle(title, for: .normal)
        }
        if let icon = icon {
            setImage(icon, for: .normal)
        }
        setupActions()
    }

    required init?(coder: NSCoder) {
        self.style = .round
        super.init(coder: coder)
        setupAppearance()
        setupActions()
    }

    private func setupAppearance() {
        backgroundColor = Theme.Colors.surface
        layer.borderColor = Theme.Colors.border.cgColor
        layer.borderWidth = 1.0
        
        titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        tintColor = Theme.Colors.textPrimary
        setTitleColor(Theme.Colors.textPrimary, for: .normal)
        
        Theme.Shadows.applyButtonShadow(to: layer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        switch style {
        case .round:
            layer.cornerRadius = bounds.width / 2.0
        case .pill:
            layer.cornerRadius = bounds.height / 2.0
        case .squareRounded:
            layer.cornerRadius = 16.0
        }
    }

    private func setupActions() {
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleTouchDown() {
        HapticManager.playTactileClick()
        
        UIView.animate(withDuration: 0.10, delay: 0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            self.backgroundColor = Theme.Colors.surfacePressed
        })
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
            self.backgroundColor = Theme.Colors.surface
        })
    }
}
