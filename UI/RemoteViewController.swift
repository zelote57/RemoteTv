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

    // MARK: - Ciclo de Vida

    override func viewDidLoad() {
        super.viewDidLoad()
        
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

    // MARK: - Notificación de Tema

    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: Theme.themeDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleThemeChanged() {
        applyTheme()
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
        headerView.addSubview(pickerContainer)

        chevronButton.isUserInteractionEnabled = false
        chevronButton.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(chevronButton)

        tvNameLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        tvNameLabel.isUserInteractionEnabled = false
        tvNameLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(tvNameLabel)

        statusDot.layer.cornerRadius = AppConstants.UI.statusDotDiameter / 2.0
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        
        statusSubtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
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
        headerActions.spacing = 12
        headerActions.alignment = .center
        headerActions.translatesAutoresizingMaskIntoConstraints = false
        
        themeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        powerButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            pickerContainer.trailingAnchor.constraint(lessThanOrEqualTo: headerActions.leadingAnchor, constant: -8),

            chevronButton.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            chevronButton.centerYAnchor.constraint(equalTo: pickerContainer.centerYAnchor),
            chevronButton.widthAnchor.constraint(equalToConstant: headerBtnSize),
            chevronButton.heightAnchor.constraint(equalToConstant: headerBtnSize),

            tvNameLabel.leadingAnchor.constraint(equalTo: chevronButton.trailingAnchor, constant: 12),
            tvNameLabel.topAnchor.constraint(equalTo: chevronButton.topAnchor, constant: 3),
            tvNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: pickerContainer.trailingAnchor),

            statusDot.widthAnchor.constraint(equalToConstant: AppConstants.UI.statusDotDiameter),
            statusDot.heightAnchor.constraint(equalToConstant: AppConstants.UI.statusDotDiameter),

            statusRow.leadingAnchor.constraint(equalTo: tvNameLabel.leadingAnchor),
            statusRow.topAnchor.constraint(equalTo: tvNameLabel.bottomAnchor, constant: 3),

            headerActions.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerActions.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

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
        themeToggleButton.addTarget(self, action: #selector(didTapThemeToggle), for: .touchUpInside)
        powerButton.addTarget(self, action: #selector(didTapPower), for: .touchUpInside)

        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(didTapHome), for: .touchUpInside)
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

        let sheet = DevicePickerSheet()
        sheet.modalPresentationStyle = .overCurrentContext
        sheet.modalTransitionStyle = .crossDissolve
        sheet.delegate = self
        sheet.devices = discovery.devices
        sheet.currentConnectedHost = client.currentHost
        sheet.isScanning = true

        discovery.startDiscovery()

        present(sheet, animated: true)
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
            showPairingDialog(for: name)
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
            tvNameLabel.text = client.currentTVName ?? L10n.Header.searchingTv
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = L10n.Status.searching
            statusSubtitleLabel.textColor = Theme.Colors.accent
            statusDot.layer.shadowOpacity = 0

        case .ready(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.connected
            statusSubtitleLabel.text = L10n.Status.connected
            statusSubtitleLabel.textColor = Theme.Colors.connected
            applyConnectedDotGlow()

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

    private func showPairingDialog(for name: String) {
        let alert = UIAlertController(
            title: L10n.Pairing.dialogTitle,
            message: L10n.Pairing.dialogMessage(deviceName: name),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = L10n.Pairing.pinPlaceholder
            tf.autocapitalizationType = .allCharacters
            tf.textAlignment = .center
            tf.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        }
        alert.addAction(UIAlertAction(title: L10n.Pairing.pairButton, style: .default, handler: { [weak self] _ in
            if let pin = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !pin.isEmpty {
                self?.client.submitPin(pin)
            }
        }))
        alert.addAction(UIAlertAction(title: L10n.Pairing.cancelButton, style: .cancel))
        present(alert, animated: true)
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
