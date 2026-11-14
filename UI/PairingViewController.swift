// PairingViewController.swift — Full-screen PIN pairing modal matching Stitch design system
// Fully compliant with Swift 5.0 and iOS 12.0+ (100% programmatic UIKit, vector CoreGraphics)

import UIKit

// MARK: - PairingViewController

class PairingViewController: UIViewController {

    // MARK: - Dependencies
    private let tvName: String
    private weak var client: GoogleTVClient?

    // MARK: - Subviews
    private let backdropView = UIView()
    private let containerView = UIView()
    private let grabberPill = UIView()

    // Header
    private let tvBadgeView = PairingTVBadgeView()
    private let titleLabel = UILabel()
    private let tvNameBadge = UILabel()
    private let closeButton = UIButton(type: .custom)

    // Instruction card
    private let instructionCard = UIView()
    private let instructionIconView = PairingInstructionIconView()
    private let instructionTitleLabel = UILabel()
    private let instructionDescLabel = UILabel()

    // PIN Input
    private let pinInputCard = UIView()
    private let pinLabel = UILabel()
    private let pinField = UITextField()
    private let pinFieldUnderline = UIView()

    // Error label (inline)
    private let errorLabel = UILabel()

    // Actions
    private let pairButton = PairingPrimaryButton()
    private let cancelButton = PairingSecondaryButton()

    // Loading spinner overlay
    private let loadingOverlay = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .white)

    // Sheet bottom constraint for slide animation
    private var containerBottomConstraint: NSLayoutConstraint?
    private var isDismissing: Bool = false

    // MARK: - Init

    init(tvName: String, client: GoogleTVClient) {
        self.tvName = tvName
        self.client = client
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupActions()
        setupNotifications()
        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatePresentation()
        pinField.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleThemeChanged),
            name: Theme.themeDidChangeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func handleThemeChanged() {
        applyTheme()
    }

    // MARK: - Keyboard handling

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardTop = UIScreen.main.bounds.height - keyboardFrame.height
        let containerBottom = UIScreen.main.bounds.height - (containerView.frame.maxY)
        let overlap = containerView.frame.maxY - keyboardTop + 16

        if overlap > 0 {
            UIView.animate(withDuration: duration) { [weak self] in
                self?.containerBottomConstraint?.constant = -overlap
                self?.view.layoutIfNeeded()
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        UIView.animate(withDuration: duration) { [weak self] in
            self?.containerBottomConstraint?.constant = 0
            self?.view.layoutIfNeeded()
        }
    }

    // MARK: - Setup Views & Auto Layout

    private func setupViews() {
        view.backgroundColor = .clear

        // 1. Backdrop
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = .clear
        view.addSubview(backdropView)

        // 2. Bottom Sheet Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 28.0
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        view.addSubview(containerView)

        // 3. Grabber pill
        grabberPill.translatesAutoresizingMaskIntoConstraints = false
        grabberPill.layer.cornerRadius = 2.5
        containerView.addSubview(grabberPill)

        // 4. TV Icon Badge (top center visual)
        tvBadgeView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(tvBadgeView)

        // 5. Title & TV Name badge
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = L10n.Pairing.dialogTitle
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)

        tvNameBadge.translatesAutoresizingMaskIntoConstraints = false
        tvNameBadge.text = " \(tvName) "
        tvNameBadge.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        tvNameBadge.textAlignment = .center
        tvNameBadge.layer.cornerRadius = 8.0
        tvNameBadge.clipsToBounds = true
        containerView.addSubview(tvNameBadge)

        // 6. Close button (top right)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        closeButton.layer.cornerRadius = 15.0
        closeButton.layer.borderWidth = 1.0
        containerView.addSubview(closeButton)

        // 7. Instruction card
        instructionCard.translatesAutoresizingMaskIntoConstraints = false
        instructionCard.layer.cornerRadius = 14.0
        instructionCard.layer.borderWidth = 1.0
        containerView.addSubview(instructionCard)

        instructionIconView.translatesAutoresizingMaskIntoConstraints = false
        instructionCard.addSubview(instructionIconView)

        instructionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionTitleLabel.text = L10n.Pairing.instructionTitle
        instructionTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        instructionCard.addSubview(instructionTitleLabel)

        instructionDescLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionDescLabel.text = L10n.Pairing.instructionDesc
        instructionDescLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        instructionDescLabel.numberOfLines = 0
        instructionCard.addSubview(instructionDescLabel)

        // 8. PIN field card
        pinInputCard.translatesAutoresizingMaskIntoConstraints = false
        pinInputCard.layer.cornerRadius = 14.0
        pinInputCard.layer.borderWidth = 1.0
        containerView.addSubview(pinInputCard)

        pinLabel.translatesAutoresizingMaskIntoConstraints = false
        pinLabel.text = L10n.Pairing.pinPlaceholder.uppercased()
        pinLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        pinInputCard.addSubview(pinLabel)

        pinField.translatesAutoresizingMaskIntoConstraints = false
        pinField.font = UIFont(name: "Menlo-Bold", size: 32) ?? UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        pinField.textAlignment = .center
        pinField.autocapitalizationType = .allCharacters
        pinField.autocorrectionType = .no
        pinField.keyboardType = .asciiCapable
        pinField.returnKeyType = .done
        pinField.delegate = self
        pinField.placeholder = "_ _ _ _ _ _"
        pinInputCard.addSubview(pinField)

        pinFieldUnderline.translatesAutoresizingMaskIntoConstraints = false
        pinFieldUnderline.layer.cornerRadius = 1.0
        pinInputCard.addSubview(pinFieldUnderline)

        // 9. Error label
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        errorLabel.textColor = Theme.Colors.error
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        containerView.addSubview(errorLabel)

        // 10. Action buttons
        pairButton.translatesAutoresizingMaskIntoConstraints = false
        pairButton.setTitle(L10n.Pairing.pairButton, for: .normal)
        containerView.addSubview(pairButton)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(L10n.Pairing.cancelButton, for: .normal)
        containerView.addSubview(cancelButton)

        // 11. Loading overlay (shown while submitting PIN)
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        loadingOverlay.isHidden = true
        containerView.addSubview(loadingOverlay)

        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.hidesWhenStopped = true
        loadingOverlay.addSubview(loadingSpinner)

        // Auto Layout
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 700)

        NSLayoutConstraint.activate([
            // Backdrop
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Container
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint!,

            // Grabber
            grabberPill.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            grabberPill.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            grabberPill.widthAnchor.constraint(equalToConstant: 40),
            grabberPill.heightAnchor.constraint(equalToConstant: 5),

            // Close Button (top-right)
            closeButton.topAnchor.constraint(equalTo: grabberPill.bottomAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            // TV Icon Badge (centered below grabber)
            tvBadgeView.topAnchor.constraint(equalTo: grabberPill.bottomAnchor, constant: 14),
            tvBadgeView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            tvBadgeView.widthAnchor.constraint(equalToConstant: 56),
            tvBadgeView.heightAnchor.constraint(equalToConstant: 56),

            // Title
            titleLabel.topAnchor.constraint(equalTo: tvBadgeView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            // TV Name Badge
            tvNameBadge.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            tvNameBadge.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            tvNameBadge.heightAnchor.constraint(equalToConstant: 20),

            // Instruction Card
            instructionCard.topAnchor.constraint(equalTo: tvNameBadge.bottomAnchor, constant: 16),
            instructionCard.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            instructionCard.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),

            instructionIconView.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 14),
            instructionIconView.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 14),
            instructionIconView.widthAnchor.constraint(equalToConstant: 32),
            instructionIconView.heightAnchor.constraint(equalToConstant: 32),
            instructionIconView.bottomAnchor.constraint(lessThanOrEqualTo: instructionCard.bottomAnchor, constant: -14),

            instructionTitleLabel.leadingAnchor.constraint(equalTo: instructionIconView.trailingAnchor, constant: 12),
            instructionTitleLabel.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -14),
            instructionTitleLabel.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 14),

            instructionDescLabel.leadingAnchor.constraint(equalTo: instructionTitleLabel.leadingAnchor),
            instructionDescLabel.trailingAnchor.constraint(equalTo: instructionTitleLabel.trailingAnchor),
            instructionDescLabel.topAnchor.constraint(equalTo: instructionTitleLabel.bottomAnchor, constant: 3),
            instructionDescLabel.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -14),

            // PIN Input Card
            pinInputCard.topAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: 14),
            pinInputCard.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            pinInputCard.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),

            pinLabel.topAnchor.constraint(equalTo: pinInputCard.topAnchor, constant: 12),
            pinLabel.centerXAnchor.constraint(equalTo: pinInputCard.centerXAnchor),

            pinField.topAnchor.constraint(equalTo: pinLabel.bottomAnchor, constant: 8),
            pinField.leadingAnchor.constraint(equalTo: pinInputCard.leadingAnchor, constant: 16),
            pinField.trailingAnchor.constraint(equalTo: pinInputCard.trailingAnchor, constant: -16),
            pinField.heightAnchor.constraint(equalToConstant: 52),

            pinFieldUnderline.topAnchor.constraint(equalTo: pinField.bottomAnchor, constant: 2),
            pinFieldUnderline.leadingAnchor.constraint(equalTo: pinInputCard.leadingAnchor, constant: 24),
            pinFieldUnderline.trailingAnchor.constraint(equalTo: pinInputCard.trailingAnchor, constant: -24),
            pinFieldUnderline.heightAnchor.constraint(equalToConstant: 2),
            pinFieldUnderline.bottomAnchor.constraint(equalTo: pinInputCard.bottomAnchor, constant: -14),

            // Error label
            errorLabel.topAnchor.constraint(equalTo: pinInputCard.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            // Pair Button
            pairButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 14),
            pairButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            pairButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            pairButton.heightAnchor.constraint(equalToConstant: 48),

            // Cancel Button
            cancelButton.topAnchor.constraint(equalTo: pairButton.bottomAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            cancelButton.heightAnchor.constraint(equalToConstant: 38),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -14),

            // Loading overlay
            loadingOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])
    }

    // MARK: - Actions

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        pairButton.addTarget(self, action: #selector(didTapPair), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        let backdropTap = UITapGestureRecognizer(target: self, action: #selector(didTapBackdrop))
        backdropTap.cancelsTouchesInView = false
        backdropView.addGestureRecognizer(backdropTap)
    }

    @objc private func didTapBackdrop() {
        pinField.resignFirstResponder()
    }

    @objc private func didTapPair() {
        let pin = pinField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pin.isEmpty else {
            showError(L10n.Pairing.errorBadPin)
            HapticManager.playError()
            return
        }

        HapticManager.playTactileClick()
        clearError()
        setLoading(true)
        pinField.resignFirstResponder()

        client?.submitPin(pin)

        // Listen for status updates to know if pairing succeeded or failed
        // The dismiss is triggered by clientDidChangeStatus in RemoteViewController
        // as it transitions to .connecting or back to .discovered(.error)
        // We wait up to 10s, then stop spinner if no response
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.setLoading(false)
        }
    }

    @objc private func didTapCancel() {
        HapticManager.playTactileClick()
        pinField.resignFirstResponder()
        dismissAnimated()
    }

    // MARK: - Presentation & Dismissal

    private func animatePresentation() {
        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: { [weak self] in
            self?.backdropView.backgroundColor = Theme.Colors.sheetBackdrop
            self?.containerBottomConstraint?.constant = 0
            self?.view.layoutIfNeeded()
        })
    }

    func dismissAnimated(completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true
        pinField.resignFirstResponder()

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn], animations: { [weak self] in
            self?.backdropView.backgroundColor = .clear
            self?.containerBottomConstraint?.constant = 700
            self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: completion)
        })
    }

    // MARK: - UI Helpers

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false

        UIView.animate(withDuration: 0.15) { [weak self] in
            self?.pinInputCard.layer.borderColor = Theme.Colors.error.cgColor
            self?.pinFieldUnderline.backgroundColor = Theme.Colors.error
        }
    }

    private func clearError() {
        errorLabel.isHidden = true
        errorLabel.text = nil
        pinInputCard.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        pinFieldUnderline.backgroundColor = Theme.Colors.accent
    }

    private func setLoading(_ loading: Bool) {
        loadingOverlay.isHidden = !loading
        if loading {
            loadingSpinner.startAnimating()
            pairButton.isEnabled = false
        } else {
            loadingSpinner.stopAnimating()
            pairButton.isEnabled = true
        }
    }

    // MARK: - Theme

    private func applyTheme() {
        containerView.backgroundColor = Theme.Colors.sheetBackground
        containerView.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        containerView.layer.borderWidth = 1.0

        grabberPill.backgroundColor = Theme.Colors.sheetGrabber

        closeButton.backgroundColor = Theme.isDark ? UIColor(white: 1.0, alpha: 0.08) : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)
        closeButton.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        closeButton.setTitleColor(Theme.Colors.textSecondary, for: .normal)

        titleLabel.textColor = Theme.Colors.textPrimary

        tvNameBadge.backgroundColor = Theme.Colors.badgeWifiBackground
        tvNameBadge.textColor = Theme.Colors.badgeWifiText

        instructionCard.backgroundColor = Theme.Colors.sheetCardBackground
        instructionCard.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        instructionIconView.applyTheme()

        instructionTitleLabel.textColor = Theme.Colors.textPrimary
        instructionDescLabel.textColor = Theme.Colors.textSecondary

        pinInputCard.backgroundColor = Theme.Colors.sheetCardBackground
        pinInputCard.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor

        pinLabel.textColor = Theme.Colors.textSecondary
        pinField.textColor = Theme.Colors.textPrimary
        pinField.tintColor = Theme.Colors.accent
        pinField.attributedPlaceholder = NSAttributedString(
            string: "_ _ _ _ _ _",
            attributes: [.foregroundColor: Theme.Colors.textSecondary.withAlphaComponent(0.5)]
        )
        pinField.keyboardAppearance = Theme.isDark ? .dark : .light

        pinFieldUnderline.backgroundColor = Theme.Colors.accent

        tvBadgeView.applyTheme()
        pairButton.applyTheme()
        cancelButton.applyTheme()
    }
}

// MARK: - UITextFieldDelegate

extension PairingViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapPair()
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Max 8 chars for a typical PIN code; clear error on typing
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        if !errorLabel.isHidden {
            clearError()
        }
        return updatedText.count <= 8
    }
}

// MARK: - PairingTVBadgeView (Vector TV screen with sync rings)

private class PairingTVBadgeView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 16.0
        layer.borderWidth = 1.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        backgroundColor = Theme.isDark
            ? UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 0.15)
            : UIColor(red: 219/255, green: 234/255, blue: 254/255, alpha: 0.8)
        layer.borderColor = Theme.Colors.badgeWifiText.withAlphaComponent(0.3).cgColor
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let iconColor = Theme.Colors.badgeWifiText
        ctx.setStrokeColor(iconColor.cgColor)
        ctx.setFillColor(iconColor.cgColor)
        ctx.setLineWidth(1.8)
        ctx.setLineCap(.round)

        // TV screen frame (22 x 15 pt)
        let tvRect = CGRect(x: rect.midX - 11, y: rect.midY - 10, width: 22, height: 14)
        let tvPath = UIBezierPath(roundedRect: tvRect, cornerRadius: 3.0)
        tvPath.lineWidth = 1.8
        tvPath.stroke()

        // TV stand
        let stand = UIBezierPath()
        stand.move(to: CGPoint(x: rect.midX, y: tvRect.maxY))
        stand.addLine(to: CGPoint(x: rect.midX, y: tvRect.maxY + 3.5))
        stand.move(to: CGPoint(x: rect.midX - 5, y: tvRect.maxY + 3.5))
        stand.addLine(to: CGPoint(x: rect.midX + 5, y: tvRect.maxY + 3.5))
        stand.lineWidth = 1.8
        stand.lineCapStyle = .round
        stand.stroke()

        // Small Wi-Fi / sync arcs inside the TV screen (pairing visual)
        let screenCenter = CGPoint(x: rect.midX, y: tvRect.midY)
        ctx.setLineWidth(1.3)

        let arc1 = UIBezierPath(arcCenter: screenCenter, radius: 4.5, startAngle: -.pi * 0.75, endAngle: -.pi * 0.25, clockwise: true)
        arc1.lineWidth = 1.3
        arc1.stroke()

        let arc2 = UIBezierPath(arcCenter: screenCenter, radius: 2.5, startAngle: -.pi * 0.75, endAngle: -.pi * 0.25, clockwise: true)
        arc2.lineWidth = 1.3
        arc2.stroke()

        ctx.fillEllipse(in: CGRect(x: screenCenter.x - 1.0, y: screenCenter.y - 1.0, width: 2.0, height: 2.0))
    }
}

// MARK: - PairingInstructionIconView (TV screen with eye indicator)

private class PairingInstructionIconView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 10.0
        layer.borderWidth = 1.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        backgroundColor = Theme.isDark
            ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15)
            : UIColor(red: 220/255, green: 252/255, blue: 231/255, alpha: 0.8)
        layer.borderColor = Theme.Colors.connected.withAlphaComponent(0.3).cgColor
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let color = Theme.Colors.connected
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)

        // Small TV icon
        let tvRect = CGRect(x: rect.midX - 8, y: rect.midY - 7, width: 16, height: 10)
        let tvPath = UIBezierPath(roundedRect: tvRect, cornerRadius: 2.5)
        tvPath.lineWidth = 1.5
        tvPath.stroke()

        // Stand
        let stand = UIBezierPath()
        stand.move(to: CGPoint(x: rect.midX, y: tvRect.maxY))
        stand.addLine(to: CGPoint(x: rect.midX, y: tvRect.maxY + 3))
        stand.move(to: CGPoint(x: rect.midX - 3, y: tvRect.maxY + 3))
        stand.addLine(to: CGPoint(x: rect.midX + 3, y: tvRect.maxY + 3))
        stand.lineWidth = 1.5
        stand.lineCapStyle = .round
        stand.stroke()

        // Pulsing dot on screen (the PIN code indicator)
        ctx.fillEllipse(in: CGRect(x: rect.midX - 1.5, y: rect.midY - 2.5, width: 3, height: 3))
    }
}

// MARK: - PairingPrimaryButton

private class PairingPrimaryButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = 14.0
        clipsToBounds = true
        titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        setTitleColor(.white, for: .normal)
        setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .disabled)
        addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        applyTheme()
    }

    func applyTheme() {
        backgroundColor = Theme.Colors.primaryButton
    }

    @objc private func handleTouchDown() {
        backgroundColor = Theme.Colors.primaryButtonPressed
        UIView.animate(withDuration: 0.1) { self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98) }
    }

    @objc private func handleTouchUp() {
        backgroundColor = Theme.Colors.primaryButton
        UIView.animate(withDuration: 0.15) { self.transform = .identity }
    }
}

// MARK: - PairingSecondaryButton

private class PairingSecondaryButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = 12.0
        layer.borderWidth = 1.0
        titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        applyTheme()
    }

    func applyTheme() {
        backgroundColor = Theme.isDark
            ? UIColor(white: 1.0, alpha: 0.05)
            : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 0.8)
        layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        setTitleColor(Theme.Colors.textSecondary, for: .normal)
    }
}
