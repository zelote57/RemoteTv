// RemoteViewController.swift — Control Remoto Google TV
// Diseño de alta fidelidad basado en Stitch (Modo Claro y Modo Oscuro)
// 100% UIKit programático, compatible con Swift 5.0 e iOS 12.0 (iPhone 6 Plus)

import UIKit

class RemoteViewController: UIViewController, GoogleTVClientDelegate, DPadViewDelegate, DevicePickerDelegate {

    // MARK: - Barra Superior (Header)
    private let headerView = UIView()
    private let pickerContainer = UIControl()
    private let chevronButton = DevicePickerChevronButton()
    private let tvNameLabel = UILabel()
    private let statusRow = UIStackView()
    private let statusDot = UIView()
    private let statusSubtitleLabel = UILabel()
    
    private let headerActions = UIStackView()
    private let settingsButton = SettingsButton()
    private let themeToggleButton = ThemeToggleButton()
    private let powerButton = PowerButton()

    // MARK: - Navegación D-Pad Central
    private let dpadView = DPadView()

    // MARK: - Fila de Acciones Inferiores (Atrás, Play/Pausa, Inicio)
    private let bottomControlsRow = UIStackView()
    private let backButton = RemoteButton(iconType: .back)
    private let playPauseButton = RemoteButton(iconType: .playPause)
    private let homeButton = RemoteButton(iconType: .home)

    // MARK: - Dependencias de Red
    private let client = GoogleTVClient.shared
    private let discovery = GoogleTVDiscovery.shared

    // MARK: - State
    /// Guards against stacking multiple PairingViewController modals.
    private var isPairingPresented: Bool = false

    // MARK: - Ciclo de Vida

    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = true
        
        client.delegate = self
        dpadView.delegate = self
        
        setupLayout()
        setupActions()
        setupThemeObserver()
        applyTheme()
        updateStatusUI(client.currentStatus)
        
        client.startAutoDiscovery()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.isDark ? .lightContent : .default
    }

    // MARK: - Notificación de Tema y Lenguaje

    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: Theme.themeDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChanged),
            name: LocalizationManager.languageDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleThemeChanged() {
        applyTheme()
        updateStatusUI(client.currentStatus)
    }

    @objc private func handleLanguageChanged() {
        updateStatusUI(client.currentStatus)
    }

    // MARK: - Layout Visual con Auto Layout

    private func setupLayout() {
        let guide = view.safeAreaLayoutGuide

        // ══════════════════════════════════════════════════
        // 1. Barra Superior (Header)
        // ══════════════════════════════════════════════════
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.clipsToBounds = false
        headerView.addSubview(pickerContainer)

        chevronButton.isUserInteractionEnabled = false
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(chevronButton)

        tvNameLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        tvNameLabel.lineBreakMode = .byTruncatingTail
        tvNameLabel.adjustsFontSizeToFitWidth = true
        tvNameLabel.minimumScaleFactor = 0.80
        tvNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tvNameLabel.isUserInteractionEnabled = false
        tvNameLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(tvNameLabel)

        statusDot.layer.cornerRadius = AppConstants.UI.statusDotDiameter / 2.0
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        
        statusSubtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusSubtitleLabel.lineBreakMode = .byTruncatingTail
        statusSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusRow.axis = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .center
        statusRow.isUserInteractionEnabled = false
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusRow.addArrangedSubview(statusDot)
        statusRow.addArrangedSubview(statusSubtitleLabel)
        pickerContainer.addSubview(statusRow)

        headerActions.axis = .horizontal
        headerActions.spacing = AppConstants.UI.headerActionsSpacing
        headerActions.alignment = .center
        headerActions.setContentCompressionResistancePriority(.required, for: .horizontal)
        headerActions.translatesAutoresizingMaskIntoConstraints = false
        
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        themeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        powerButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerActions.addArrangedSubview(settingsButton)
        headerActions.addArrangedSubview(themeToggleButton)
        headerActions.addArrangedSubview(powerButton)
        headerView.addSubview(headerActions)

        // ══════════════════════════════════════════════════
        // 2. D-Pad Central
        // ══════════════════════════════════════════════════
        dpadView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dpadView)

        // ══════════════════════════════════════════════════
        // 3. Fila de Acciones Inferiores (Atrás, Play/Pausa, Inicio)
        // ══════════════════════════════════════════════════
        bottomControlsRow.axis = .horizontal
        bottomControlsRow.spacing = AppConstants.UI.actionsRowSpacing
        bottomControlsRow.alignment = .center
        bottomControlsRow.distribution = .equalSpacing
        bottomControlsRow.translatesAutoresizingMaskIntoConstraints = false
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        
        bottomControlsRow.addArrangedSubview(backButton)
        bottomControlsRow.addArrangedSubview(playPauseButton)
        bottomControlsRow.addArrangedSubview(homeButton)
        view.addSubview(bottomControlsRow)

        // Dimensiones estandarizadas
        let dpadSize = AppConstants.UI.dpadDiameter
        let actionBtnSize = AppConstants.UI.actionButtonSize
        let headerBtnSize = AppConstants.UI.headerButtonSize

        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: AppConstants.UI.headerTopOffset),
            headerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: AppConstants.UI.headerHorizontalInset),
            headerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -AppConstants.UI.headerHorizontalInset),
            headerView.heightAnchor.constraint(equalToConstant: AppConstants.UI.headerHeight),

            pickerContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            pickerContainer.topAnchor.constraint(equalTo: headerView.topAnchor),
            pickerContainer.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            pickerContainer.trailingAnchor.constraint(equalTo: headerActions.leadingAnchor, constant: -10),

            chevronButton.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            chevronButton.centerYAnchor.constraint(equalTo: pickerContainer.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: headerBtnSize),
            chevronButton.heightAnchor.constraint(equalToConstant: headerBtnSize),

            tvNameLabel.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: 10),
            tvNameLabel.topAnchor.constraint(equalTo: chevronButton.topAnchor, constant: 2),
            tvNameLabel.trailingAnchor.constraint(equalTo: pickerContainer.trailingAnchor),

            statusDot.widthAnchor.constraint(equalToConstant: AppConstants.UI.statusDotDiameter),
            statusDot.heightAnchor.constraint(equalToConstant: AppConstants.UI.statusDotDiameter),

            statusRow.leadingAnchor.constraint(equalTo: tvNameLabel.leadingAnchor),
            statusRow.topAnchor.constraint(equalTo: tvNameLabel.bottomAnchor, constant: 3),
            statusRow.trailingAnchor.constraint(lessThanOrEqualTo: pickerContainer.trailingAnchor),

            headerActions.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerActions.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            settingsButton.widthAnchor.constraint(equalToConstant: headerBtnSize),
            settingsButton.heightAnchor.constraint(equalToConstant: headerBtnSize),

            themeToggleButton.widthAnchor.constraint(equalToConstant: headerBtnSize),
            themeToggleButton.heightAnchor.constraint(equalToConstant: headerBtnSize),

            powerButton.widthAnchor.constraint(equalToConstant: headerBtnSize),
            powerButton.heightAnchor.constraint(equalToConstant: headerBtnSize),

            // D-Pad centrado en el medio de la pantalla
            dpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dpadView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: AppConstants.UI.centerVerticalOffset),
            dpadView.widthAnchor.constraint(equalToConstant: dpadSize),
            dpadView.heightAnchor.constraint(equalToConstant: dpadSize),

            // Fila de acciones anclada armónicamente en la parte inferior
            bottomControlsRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomControlsRow.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 28),
            bottomControlsRow.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -28),
            bottomControlsRow.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -28),

            backButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            backButton.heightAnchor.constraint(equalToConstant: actionBtnSize),

            playPauseButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: actionBtnSize),

            homeButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            homeButton.heightAnchor.constraint(equalToConstant: actionBtnSize)
        ])
    }

    // MARK: - Aplicación de Tema (Modo Claro / Modo Oscuro)

    private func applyTheme() {
        view.backgroundColor = Theme.Colors.background

        tvNameLabel.textColor = Theme.Colors.textPrimary
        
        chevronButton.applyTheme()
        settingsButton.applyTheme()
        themeToggleButton.applyTheme()
        powerButton.applyTheme()
        dpadView.applyTheme()
        
        backButton.applyTheme()
        playPauseButton.applyTheme()
        homeButton.applyTheme()

        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Acciones de Usuario

    private func setupActions() {
        pickerContainer.addTarget(self, action: #selector(didTapDevicePicker), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)
        themeToggleButton.addTarget(self, action: #selector(didTapThemeToggle), for: .touchUpInside)
        powerButton.addTarget(self, action: #selector(didTapPower), for: .touchUpInside)

        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(didTapHome), for: .touchUpInside)
    }

    @objc private func didTapSettings() {
        HapticManager.playTactileClick()
        let sheet = SettingsSheet()
        sheet.modalPresentationStyle = .overCurrentContext
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    @objc private func didTapThemeToggle() {
        Theme.toggleTheme()
        
        UIView.animate(withDuration: AppConstants.UI.defaultAnimationDuration) { [weak self] in
            self?.applyTheme()
            if let currentStatus = self?.client.currentStatus {
                self?.updateStatusUI(currentStatus)
            }
        }
    }

    // MARK: - D-Pad Delegate

    func dpadDidTapUp(_ dpad: DPadView) { client.sendKey(.dpadUp) }
    func dpadDidTapDown(_ dpad: DPadView) { client.sendKey(.dpadDown) }
    func dpadDidTapLeft(_ dpad: DPadView) { client.sendKey(.dpadLeft) }
    func dpadDidTapRight(_ dpad: DPadView) { client.sendKey(.dpadRight) }
    func dpadDidTapCenter(_ dpad: DPadView) { client.sendKey(.dpadCenter) }

    // MARK: - Acciones de Botones

    @objc private func didTapPower() { client.sendKey(.power) }
    @objc private func didTapBack() { client.sendKey(.back) }
    @objc private func didTapPlayPause() { client.sendKey(.mediaPlayPause) }
    @objc private func didTapHome() { client.sendKey(.home) }

    // MARK: - Selector de Dispositivos (Device Picker)

    @objc private func didTapDevicePicker() {
        HapticManager.playTactileClick()
        guard presentedViewController == nil else { return }

        let sheet = DevicePickerSheet()
        sheet.modalPresentationStyle = .overCurrentContext
        sheet.modalTransitionStyle = .crossDissolve
        sheet.delegate = self
        sheet.devices = discovery.devices
        if case .connected = client.currentStatus {
            sheet.currentConnectedHost = client.currentHost
        } else {
            sheet.currentConnectedHost = nil
        }
        sheet.isScanning = true

        present(sheet, animated: true) { [weak self] in
            self?.discovery.startDiscovery()
        }
    }

    // MARK: - DevicePickerDelegate

    func devicePickerDidSelectDevice(_ picker: DevicePickerSheet, device: DiscoveredTV) {
        client.connect(to: device)
    }

    func devicePickerDidRequestScanAgain(_ picker: DevicePickerSheet) {
        discovery.startDiscovery()
    }

    // MARK: - Client Delegate & Estado Visual

    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus) {
        updateStatusUI(status)

        if case .pairingRequired(let name) = status {
            showPairingViewController(for: name)
        }

        // Forward status changes to PairingVC if currently presented
        if let pairingVC = presentedViewController as? PairingViewController {
            pairingVC.handleStatusChange(status)
        }
    }

    private func updateStatusUI(_ status: ConnectionStatus) {
        switch status {
        case .disconnected:
            tvNameLabel.text = client.currentTVName ?? L10n.Header.selectTv
            statusDot.backgroundColor = Theme.Colors.disconnected
            statusSubtitleLabel.text = L10n.Status.disconnected
            statusSubtitleLabel.textColor = Theme.Colors.textSecondary
            statusDot.layer.shadowOpacity = 0

        case .searching:
            tvNameLabel.text = L10n.Header.searchingTv
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = L10n.Status.searching
            statusSubtitleLabel.textColor = Theme.Colors.accent
            statusDot.layer.shadowOpacity = 0

        case .discovered(let name):
            // TV found on network, NOT connected — show amber "Available" indicator
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.sunYellow
            statusSubtitleLabel.text = L10n.Status.discovered
            statusSubtitleLabel.textColor = Theme.Colors.sunYellow
            statusDot.layer.shadowOpacity = 0

        case .connecting(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = L10n.Status.connecting
            statusSubtitleLabel.textColor = Theme.Colors.accent
            statusDot.layer.shadowOpacity = 0

        case .pairingRequired(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = L10n.Status.pairingRequired
            statusSubtitleLabel.textColor = Theme.Colors.accent
            statusDot.layer.shadowOpacity = 0

        case .connected(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.connected
            statusSubtitleLabel.text = L10n.Status.connected
            statusSubtitleLabel.textColor = Theme.Colors.connected
            applyConnectedDotGlow()

        case .error(let msg):
            tvNameLabel.text = client.currentTVName ?? L10n.Header.tvError
            statusDot.backgroundColor = Theme.Colors.error
            statusSubtitleLabel.text = L10n.Status.error(msg)
            statusSubtitleLabel.textColor = Theme.Colors.error
            statusDot.layer.shadowOpacity = 0
        }

        let isConnected: Bool
        if case .connected = status {
            isConnected = true
        } else {
            isConnected = false
        }
        updateRemoteControlsEnabledState(isConnected)
    }

    private func updateRemoteControlsEnabledState(_ isConnected: Bool, animated: Bool = true) {
        let targetAlpha: CGFloat = isConnected ? 1.0 : AppConstants.UI.standbyControlAlpha
        let duration: TimeInterval = animated ? AppConstants.UI.defaultAnimationDuration : 0.0

        UIView.animate(withDuration: duration) { [weak self] in
            guard let self = self else { return }
            self.powerButton.alpha = targetAlpha
            self.dpadView.alpha = targetAlpha
            self.bottomControlsRow.alpha = targetAlpha
        }

        powerButton.isUserInteractionEnabled = isConnected
        dpadView.isUserInteractionEnabled = isConnected
        backButton.isUserInteractionEnabled = isConnected
        playPauseButton.isUserInteractionEnabled = isConnected
        homeButton.isUserInteractionEnabled = isConnected
    }

    private func applyConnectedDotGlow() {
        if Theme.isDark {
            statusDot.layer.shadowColor = Theme.Colors.connected.cgColor
            statusDot.layer.shadowOffset = .zero
            statusDot.layer.shadowRadius = 3.0
            statusDot.layer.shadowOpacity = 0.80
        } else {
            statusDot.layer.shadowOpacity = 0
        }
    }

    private func showPairingViewController(for tvName: String) {
        guard !isPairingPresented else { return }
        isPairingPresented = true
        let pairingVC = PairingViewController(tvName: tvName, client: client)
        pairingVC.modalPresentationStyle = .overFullScreen
        pairingVC.modalTransitionStyle = .crossDissolve
        pairingVC.onDismiss = { [weak self] in
            self?.isPairingPresented = false
        }

        if let presented = presentedViewController, !presented.isBeingDismissed {
            presented.dismiss(animated: true) { [weak self] in
                self?.present(pairingVC, animated: true)
            }
        } else {
            present(pairingVC, animated: true)
        }
    }
}

// MARK: - Componente Vectorial: Botón de Sol / Brillo (ThemeToggle)

private class ThemeToggleButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

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
        clipsToBounds = false
        contentMode = .redraw
        
        applyTheme()
        
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
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

        // 1. Círculo de superficie puro
        let circleRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let circlePath = UIBezierPath(ovalIn: circleRect)

        let surfaceColor = isHighlighted ? Theme.Colors.surfacePressed : Theme.Colors.surface
        ctx.setFillColor(surfaceColor.cgColor)
        circlePath.fill()

        ctx.setStrokeColor(Theme.Colors.border.cgColor)
        ctx.setLineWidth(1.0)
        circlePath.stroke()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let sunColor = Theme.Colors.sunYellow

        // 2. Círculo Central del Sol
        let coreRadius: CGFloat = 4.8
        ctx.setFillColor(sunColor.cgColor)
        ctx.fillEllipse(in: CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2.0,
            height: coreRadius * 2.0
        ))

        // 3. Ocho Rayos Solares Concéntricos
        ctx.setStrokeColor(sunColor.cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)

        let innerDist: CGFloat = 7.5
        let outerDist: CGFloat = 10.5

        for i in 0..<8 {
            let angle = (CGFloat(i) * CGFloat.pi / 4.0)
            let cosA = cos(angle)
            let sinA = sin(angle)

            let pStart = CGPoint(x: center.x + innerDist * cosA, y: center.y + innerDist * sinA)
            let pEnd = CGPoint(x: center.x + outerDist * cosA, y: center.y + outerDist * sinA)

            let ray = UIBezierPath()
            ray.move(to: pStart)
            ray.addLine(to: pEnd)
            ray.lineWidth = 2.0
            ray.lineCapStyle = .round
            ray.stroke()
        }
    }
}

// MARK: - Componente Vectorial: Botón Selector de Dispositivo (Chevron)

private class DevicePickerChevronButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

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
        clipsToBounds = false
        contentMode = .redraw
        
        applyTheme()
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

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 1. Círculo de superficie puro
        let circleRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let circlePath = UIBezierPath(ovalIn: circleRect)

        let surfaceColor = isHighlighted ? Theme.Colors.surfacePressed : Theme.Colors.surface
        ctx.setFillColor(surfaceColor.cgColor)
        circlePath.fill()

        ctx.setStrokeColor(Theme.Colors.border.cgColor)
        ctx.setLineWidth(1.0)
        circlePath.stroke()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let chevronColor = Theme.Colors.textPrimary

        // 2. Flecha triangular hacia abajo exacta a Stitch SVG (d="M7 10l5 5 5-5z")
        ctx.setFillColor(chevronColor.cgColor)

        let triangle = UIBezierPath()
        let halfWidth: CGFloat = 5.5
        let topY: CGFloat = center.y - 2.5
        let bottomY: CGFloat = center.y + 3.5

        triangle.move(to: CGPoint(x: center.x - halfWidth, y: topY))
        triangle.addLine(to: CGPoint(x: center.x + halfWidth, y: topY))
        triangle.addLine(to: CGPoint(x: center.x, y: bottomY))
        triangle.close()
        triangle.fill()
    }
}

// MARK: - Componente Vectorial: Botón de Configuración (SettingsButton)

private class SettingsButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

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
        clipsToBounds = false
        contentMode = .redraw
        
        applyTheme()
        
        addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
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

        // 1. Círculo de superficie puro
        let circleRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let circlePath = UIBezierPath(ovalIn: circleRect)

        let surfaceColor = isHighlighted ? Theme.Colors.surfacePressed : Theme.Colors.surface
        ctx.setFillColor(surfaceColor.cgColor)
        circlePath.fill()

        ctx.setStrokeColor(Theme.Colors.border.cgColor)
        ctx.setLineWidth(1.0)
        circlePath.stroke()

        // 2. Icono de Engranaje / Configuración Mecánico (6 dientes anchos, estilo iOS Settings)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let iconColor = Theme.Colors.textPrimary
        let toothCount = 6
        let outerRadius: CGFloat = 9.0
        let rootRadius: CGFloat = 6.8
        let holeRadius: CGFloat = 2.8
        
        let tipHalfAngle: CGFloat = 12.0 * (.pi / 180.0)   // 12° a cada lado (cresta de 24°)
        let baseHalfAngle: CGFloat = 16.5 * (.pi / 180.0)  // 16.5° a cada lado (base de 33°)
        let stepAngle: CGFloat = (.pi * 2.0) / CGFloat(toothCount) // 60° entre dientes

        let gearPath = UIBezierPath()

        for i in 0..<toothCount {
            let toothAngle = CGFloat(i) * stepAngle
            let tipStart = toothAngle - tipHalfAngle
            let tipEnd = toothAngle + tipHalfAngle
            let baseEnd = toothAngle + baseHalfAngle
            
            let nextToothAngle = CGFloat(i + 1) * stepAngle
            let nextBaseStart = nextToothAngle - baseHalfAngle
            let nextTipStart = nextToothAngle - tipHalfAngle

            if i == 0 {
                let startPt = CGPoint(
                    x: center.x + outerRadius * cos(tipStart),
                    y: center.y + outerRadius * sin(tipStart)
                )
                gearPath.move(to: startPt)
            }

            // Cresta del diente (arco exterior plano y ancho)
            gearPath.addArc(withCenter: center, radius: outerRadius, startAngle: tipStart, endAngle: tipEnd, clockwise: true)

            // Flanco descendente hacia la raíz
            let valleyStartPt = CGPoint(
                x: center.x + rootRadius * cos(baseEnd),
                y: center.y + rootRadius * sin(baseEnd)
            )
            gearPath.addLine(to: valleyStartPt)

            // Arco del valle entre dientes
            gearPath.addArc(withCenter: center, radius: rootRadius, startAngle: baseEnd, endAngle: nextBaseStart, clockwise: true)

            // Flanco ascendente hacia la cresta del siguiente diente
            let nextTipPt = CGPoint(
                x: center.x + outerRadius * cos(nextTipStart),
                y: center.y + outerRadius * sin(nextTipStart)
            )
            gearPath.addLine(to: nextTipPt)
        }
        gearPath.close()

        // Orificio central circular limpio
        let holeRect = CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2.0, height: holeRadius * 2.0)
        gearPath.append(UIBezierPath(ovalIn: holeRect))
        gearPath.usesEvenOddFillRule = true

        ctx.setFillColor(iconColor.cgColor)
        gearPath.fill()
    }
}
