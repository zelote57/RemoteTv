import UIKit

protocol DPadViewDelegate: AnyObject {
    func dpadDidTapUp(_ dpad: DPadView)
    func dpadDidTapDown(_ dpad: DPadView)
    func dpadDidTapLeft(_ dpad: DPadView)
    func dpadDidTapRight(_ dpad: DPadView)
    func dpadDidTapCenter(_ dpad: DPadView)
}

class DPadView: UIView {

    weak var delegate: DPadViewDelegate?

    private let upButton = UIButton(type: .custom)
    private let downButton = UIButton(type: .custom)
    private let leftButton = UIButton(type: .custom)
    private let rightButton = UIButton(type: .custom)
    private let centerButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        configureDirectionButton(upButton, title: "▲", action: #selector(didTapUp))
        configureDirectionButton(downButton, title: "▼", action: #selector(didTapDown))
        configureDirectionButton(leftButton, title: "◀", action: #selector(didTapLeft))
        configureDirectionButton(rightButton, title: "▶", action: #selector(didTapRight))

        centerButton.setTitle("OK", for: .normal)
        centerButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        centerButton.layer.borderWidth = 1.0
        centerButton.addTarget(self, action: #selector(didTapCenter), for: .touchUpInside)
        addPressAnimation(to: centerButton)

        addSubview(upButton)
        addSubview(downButton)
        addSubview(leftButton)
        addSubview(rightButton)
        addSubview(centerButton)

        applyTheme()
    }

    func applyTheme() {
        backgroundColor = Theme.Colors.dpadOuter
        layer.borderColor = Theme.Colors.border.cgColor
        layer.borderWidth = 1.0
        Theme.Shadows.applySoftCard(to: layer)

        centerButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)
        centerButton.backgroundColor = Theme.Colors.dpadCenter
        centerButton.layer.borderColor = Theme.Colors.border.cgColor
        Theme.Shadows.applyButtonShadow(to: centerButton.layer)

        for btn in [upButton, downButton, leftButton, rightButton] {
            btn.setTitleColor(Theme.Colors.textSecondary, for: .normal)
        }
    }

    private func configureDirectionButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.addTarget(self, action: action, for: .touchUpInside)
        addPressAnimation(to: button)
    }

    private func addPressAnimation(to button: UIButton) {
        button.addTarget(self, action: #selector(btnDown(_:)), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(btnUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func btnDown(_ sender: UIButton) {
        HapticManager.playTactileClick()
        
        UIView.animate(withDuration: 0.10) {
            sender.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            sender.backgroundColor = Theme.Colors.surfacePressed
        }
    }

    @objc private func btnUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.20, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            sender.transform = .identity
            sender.backgroundColor = sender == self.centerButton ? Theme.Colors.dpadCenter : .clear
        })
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.width
        layer.cornerRadius = size / 2.0

        let centerSize: CGFloat = size * 0.42
        let centerOrigin = (size - centerSize) / 2.0
        centerButton.frame = CGRect(x: centerOrigin, y: centerOrigin, width: centerSize, height: centerSize)
        centerButton.layer.cornerRadius = centerSize / 2.0

        let armLength = centerOrigin
        upButton.frame = CGRect(x: centerOrigin, y: 0, width: centerSize, height: armLength)
        downButton.frame = CGRect(x: centerOrigin, y: size - armLength, width: centerSize, height: armLength)
        leftButton.frame = CGRect(x: 0, y: centerOrigin, width: armLength, height: centerSize)
        rightButton.frame = CGRect(x: size - armLength, y: centerOrigin, width: armLength, height: centerSize)
    }

    @objc private func didTapUp() { delegate?.dpadDidTapUp(self) }
    @objc private func didTapDown() { delegate?.dpadDidTapDown(self) }
    @objc private func didTapLeft() { delegate?.dpadDidTapLeft(self) }
    @objc private func didTapRight() { delegate?.dpadDidTapRight(self) }
    @objc private func didTapCenter() { delegate?.dpadDidTapCenter(self) }
}
