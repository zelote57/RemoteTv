import UIKit

class RemoteButton: UIButton {

    enum Style {
        case round
        case pill
        case squareRounded
        case power
    }

    private let style: Style
    private var feedbackGenerator: Any? // UIImpactFeedbackGenerator para iOS 10+

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
        
        titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        
        if style == .power {
            tintColor = Theme.Colors.power
            setTitleColor(Theme.Colors.power, for: .normal)
        } else {
            tintColor = Theme.Colors.iconDark
            setTitleColor(Theme.Colors.textPrimary, for: .normal)
        }
        
        Theme.Shadows.applyButtonShadow(to: layer)
        
        // Haptic Feedback Generator (compatible con iOS 10+)
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            self.feedbackGenerator = generator
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        switch style {
        case .round:
            layer.cornerRadius = bounds.width / 2.0
        case .pill:
            layer.cornerRadius = bounds.height / 2.0
        case .squareRounded, .power:
            layer.cornerRadius = 16.0
        }
    }

    private func setupActions() {
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleTouchDown() {
        if #available(iOS 10.0, *), let gen = feedbackGenerator as? UIImpactFeedbackGenerator {
            gen.impactOccurred()
        }
        
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.backgroundColor = Theme.Colors.surfacePressed
        })
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.transform = .identity
            self.backgroundColor = Theme.Colors.surface
        })
    }
}
