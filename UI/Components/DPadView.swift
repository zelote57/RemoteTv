// DPadView.swift — Circular 5-way directional control matching Stitch design
// Fully compliant with Swift 5.0 and iOS 12.0+ (100% vector rendering for iPhone 6 Plus)

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

    private let upButton = DPadDirectionButton(direction: .up)
    private let downButton = DPadDirectionButton(direction: .down)
    private let leftButton = DPadDirectionButton(direction: .left)
    private let rightButton = DPadDirectionButton(direction: .right)
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
        clipsToBounds = false

        upButton.addTarget(self, action: #selector(didTapUp), for: .touchUpInside)
        downButton.addTarget(self, action: #selector(didTapDown), for: .touchUpInside)
        leftButton.addTarget(self, action: #selector(didTapLeft), for: .touchUpInside)
        rightButton.addTarget(self, action: #selector(didTapRight), for: .touchUpInside)

        centerButton.setTitle("OK", for: .normal)
        centerButton.titleLabel?.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        centerButton.layer.borderWidth = 1.0
        centerButton.addTarget(self, action: #selector(didTapCenter), for: .touchUpInside)
        
        centerButton.addTarget(self, action: #selector(centerBtnDown), for: [.touchDown, .touchDragEnter])
        centerButton.addTarget(self, action: #selector(centerBtnUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

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
        Theme.Shadows.applyDpadOuterShadow(to: layer)

        centerButton.backgroundColor = Theme.Colors.dpadCenter
        centerButton.layer.borderColor = Theme.Colors.border.cgColor
        centerButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)
        Theme.Shadows.applyDpadCenterShadow(to: centerButton.layer)

        upButton.applyTheme()
        downButton.applyTheme()
        leftButton.applyTheme()
        rightButton.applyTheme()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.width
        guard size > 0 else { return }

        layer.cornerRadius = size / 2.0
        Theme.Shadows.applyDpadOuterShadow(to: layer)

        // Center OK button dimensions (120 pt on standard size)
        let centerSize: CGFloat = size * AppConstants.UI.dpadCenterRatio
        let centerOrigin = (size - centerSize) / 2.0
        centerButton.frame = CGRect(x: centerOrigin, y: centerOrigin, width: centerSize, height: centerSize)
        centerButton.layer.cornerRadius = centerSize / 2.0
        Theme.Shadows.applyDpadCenterShadow(to: centerButton.layer)

        let armLength = centerOrigin
        upButton.frame = CGRect(x: centerOrigin, y: 0, width: centerSize, height: armLength)
        downButton.frame = CGRect(x: centerOrigin, y: size - armLength, width: centerSize, height: armLength)
        leftButton.frame = CGRect(x: 0, y: centerOrigin, width: armLength, height: centerSize)
        rightButton.frame = CGRect(x: size - armLength, y: centerOrigin, width: armLength, height: centerSize)
    }

    @objc private func centerBtnDown() {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.10, delay: 0, options: [.curveEaseOut], animations: {
            self.centerButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.centerButton.backgroundColor = Theme.Colors.surfacePressed
        })
    }

    @objc private func centerBtnUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            self.centerButton.transform = .identity
            self.centerButton.backgroundColor = Theme.Colors.dpadCenter
        })
    }

    @objc private func didTapUp() { delegate?.dpadDidTapUp(self) }
    @objc private func didTapDown() { delegate?.dpadDidTapDown(self) }
    @objc private func didTapLeft() { delegate?.dpadDidTapLeft(self) }
    @objc private func didTapRight() { delegate?.dpadDidTapRight(self) }
    @objc private func didTapCenter() { delegate?.dpadDidTapCenter(self) }
}

// MARK: - Vector Arrow Directional Button
private class DPadDirectionButton: UIButton {

    enum Direction {
        case up
        case down
        case left
        case right
    }

    private let direction: Direction

    init(direction: Direction) {
        self.direction = direction
        super.init(frame: .zero)
        backgroundColor = .clear
        contentMode = .redraw
        clipsToBounds = true

        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) {
        self.direction = .up
        super.init(coder: coder)
    }

    func applyTheme() {
        setNeedsDisplay()
    }

    @objc private func handleTouchDown() {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.08) {
            self.backgroundColor = Theme.Colors.surfacePressed.withAlphaComponent(0.40)
        }
    }

    @objc private func handleTouchUp() {
        UIView.animate(withDuration: 0.18) {
            self.backgroundColor = .clear
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setFillColor(Theme.Colors.textSecondary.cgColor)

        let arrowSize: CGFloat = 13.0
        let path = UIBezierPath()

        switch direction {
        case .up:
            let centerX = rect.midX
            let topY = rect.minY + 20.0
            path.move(to: CGPoint(x: centerX, y: topY))
            path.addLine(to: CGPoint(x: centerX - (arrowSize * 0.65), y: topY + arrowSize))
            path.addLine(to: CGPoint(x: centerX + (arrowSize * 0.65), y: topY + arrowSize))
            path.close()

        case .down:
            let centerX = rect.midX
            let bottomY = rect.maxY - 20.0
            path.move(to: CGPoint(x: centerX, y: bottomY))
            path.addLine(to: CGPoint(x: centerX - (arrowSize * 0.65), y: bottomY - arrowSize))
            path.addLine(to: CGPoint(x: centerX + (arrowSize * 0.65), y: bottomY - arrowSize))
            path.close()

        case .left:
            let leftX = rect.minX + 20.0
            let centerY = rect.midY
            path.move(to: CGPoint(x: leftX, y: centerY))
            path.addLine(to: CGPoint(x: leftX + arrowSize, y: centerY - (arrowSize * 0.65)))
            path.addLine(to: CGPoint(x: leftX + arrowSize, y: centerY + (arrowSize * 0.65)))
            path.close()

        case .right:
            let rightX = rect.maxX - 20.0
            let centerY = rect.midY
            path.move(to: CGPoint(x: rightX, y: centerY))
            path.addLine(to: CGPoint(x: rightX - arrowSize, y: centerY - (arrowSize * 0.65)))
            path.addLine(to: CGPoint(x: rightX - arrowSize, y: centerY + (arrowSize * 0.65)))
            path.close()
        }

        path.fill()
    }
}
