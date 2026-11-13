// RemoteViewController.swift — Control Remoto Google TV
// Diseño Minimalista y equilibrado en el centro de la pantalla
// Soporte completo de Tema Claro y Oscuro (idéntico diseño en ambos)
// Optimizado para iPhone 6 Plus (iOS 12.0) sin letterboxing

import UIKit

class RemoteViewController: UIViewController, GoogleTVClientDelegate, DPadViewDelegate, DevicePickerDelegate {

    // MARK: - Barra Superior (Header)
    private let headerView = UIView()
    private let pickerContainer = UIControl()
    private let pickerChevronCircle = UIView()
    private let pickerChevronLabel = UILabel()
    private let tvNameLabel = UILabel()
    private let statusRow = UIStackView()
    private let statusDot = UIView()
    private let statusSubtitleLabel = UILabel()
    
    private let headerActions = UIStackView()
    private let themeToggleButton = UIButton(type: .custom)
    private let powerButton = PowerButton(type: .custom)

    // MARK: - Contenedor Central (Equilibrado verticalmente)
    private let centerContentContainer = UIView()
    private let dpadView = DPadView()

    // MARK: - Fila de Acciones Principales (Atrás, Play/Pausa, Home)
    private let backButton = RemoteButton(title: "←", style: .round)
    private let playPauseButton = RemoteButton(title: "⏯", style: .round)
    private let homeButton = RemoteButton(title: "⌂", style: .round)

    private let client = GoogleTVClient.shared
    private let discovery = GoogleTVDiscovery.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        
        client.delegate = self
        dpadView.delegate = self
        
        setupLayout()
        setupActions()
        applyTheme()
        updateStatusUI(client.currentStatus)
        
        client.startAutoDiscovery()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.isDark ? .lightContent : .default
    }

    // MARK: - Layout Visual

    private func setupLayout() {
        let guide = view.safeAreaLayoutGuide

        // ══════════════════════════════════════════════════
        // 1. Barra Superior (Header)
        // ══════════════════════════════════════════════════
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(pickerContainer)

        pickerChevronCircle.layer.cornerRadius = 22.0
        pickerChevronCircle.layer.borderWidth = 1.0
        pickerChevronCircle.isUserInteractionEnabled = false
        pickerChevronCircle.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(pickerChevronCircle)

        pickerChevronLabel.text = "▼"
        pickerChevronLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        pickerChevronLabel.textAlignment = .center
        pickerChevronLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerChevronCircle.addSubview(pickerChevronLabel)

        tvNameLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        tvNameLabel.isUserInteractionEnabled = false
        tvNameLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(tvNameLabel)

        statusDot.layer.cornerRadius = 3.5
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

        // Botón de Alternancia de Tema (☀️ Modo Claro / 🌙 Modo Oscuro)
        themeToggleButton.layer.cornerRadius = 20.0
        themeToggleButton.layer.borderWidth = 1.0
        themeToggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        themeToggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        powerButton.translatesAutoresizingMaskIntoConstraints = false

        headerActions.axis = .horizontal
        headerActions.spacing = 12
        headerActions.alignment = .center
        headerActions.translatesAutoresizingMaskIntoConstraints = false
        headerActions.addArrangedSubview(themeToggleButton)
        headerActions.addArrangedSubview(powerButton)
        headerView.addSubview(headerActions)

        // ══════════════════════════════════════════════════
        // 2. Contenedor Central (Ocupa el centro armónico de la pantalla)
        // ══════════════════════════════════════════════════
        centerContentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerContentContainer)

        dpadView.translatesAutoresizingMaskIntoConstraints = false
        centerContentContainer.addSubview(dpadView)

        // Fila de acciones principales 100% funcionales (Atrás, Play/Pausa, Inicio)
        let actionsRow = UIStackView(arrangedSubviews: [backButton, playPauseButton, homeButton])
        actionsRow.axis = .horizontal
        actionsRow.spacing = 32
        actionsRow.alignment = .center
        actionsRow.distribution = .equalSpacing
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        centerContentContainer.addSubview(actionsRow)

        // Dimensiones calculadas para iPhone 6 Plus (414 x 736 pt)
        let dpadSize: CGFloat = 268
        let actionBtnSize: CGFloat = 72

        NSLayoutConstraint.activate([
            // Header fijado arriba
            headerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 48),

            pickerContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            pickerContainer.topAnchor.constraint(equalTo: headerView.topAnchor),
            pickerContainer.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            pickerContainer.trailingAnchor.constraint(lessThanOrEqualTo: headerActions.leadingAnchor, constant: -10),

            pickerChevronCircle.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            pickerChevronCircle.centerYAnchor.constraint(equalTo: pickerContainer.centerYAnchor),
            pickerChevronCircle.widthAnchor.constraint(equalToConstant: 44),
            pickerChevronCircle.heightAnchor.constraint(equalToConstant: 44),

            pickerChevronLabel.centerXAnchor.constraint(equalTo: pickerChevronCircle.centerXAnchor),
            pickerChevronLabel.centerYAnchor.constraint(equalTo: pickerChevronCircle.centerYAnchor),

            tvNameLabel.leadingAnchor.constraint(equalTo: pickerChevronCircle.trailingAnchor, constant: 12),
            tvNameLabel.topAnchor.constraint(equalTo: pickerChevronCircle.topAnchor, constant: 2),

            statusDot.widthAnchor.constraint(equalToConstant: 7),
            statusDot.heightAnchor.constraint(equalToConstant: 7),

            statusRow.leadingAnchor.constraint(equalTo: tvNameLabel.leadingAnchor),
            statusRow.topAnchor.constraint(equalTo: tvNameLabel.bottomAnchor, constant: 3),

            headerActions.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerActions.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            themeToggleButton.widthAnchor.constraint(equalToConstant: 40),
            themeToggleButton.heightAnchor.constraint(equalToConstant: 40),

            powerButton.widthAnchor.constraint(equalToConstant: 46),
            powerButton.heightAnchor.constraint(equalToConstant: 46),

            // Contenedor centrado en la pantalla (dejando balance perfecto arriba y abajo)
            centerContentContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerContentContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 28),
            centerContentContainer.widthAnchor.constraint(equalToConstant: dpadSize),

            // D-Pad
            dpadView.topAnchor.constraint(equalTo: centerContentContainer.topAnchor),
            dpadView.centerXAnchor.constraint(equalTo: centerContentContainer.centerXAnchor),
            dpadView.widthAnchor.constraint(equalToConstant: dpadSize),
            dpadView.heightAnchor.constraint(equalToConstant: dpadSize),

            // Fila de acciones
            actionsRow.topAnchor.constraint(equalTo: dpadView.bottomAnchor, constant: 46),
            actionsRow.centerXAnchor.constraint(equalTo: centerContentContainer.centerXAnchor),
            actionsRow.bottomAnchor.constraint(equalTo: centerContentContainer.bottomAnchor),

            backButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            backButton.heightAnchor.constraint(equalToConstant: actionBtnSize),

            playPauseButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: actionBtnSize),

            homeButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            homeButton.heightAnchor.constraint(equalToConstant: actionBtnSize)
        ])
    }

    // MARK: - Soporte de Tema Dinámico (Claro / Oscuro)

    private func applyTheme() {
        view.backgroundColor = Theme.Colors.background

        pickerChevronCircle.backgroundColor = Theme.Colors.surface
        pickerChevronCircle.layer.borderColor = Theme.Colors.border.cgColor
        pickerChevronLabel.textColor = Theme.Colors.textPrimary
        tvNameLabel.textColor = Theme.Colors.textPrimary

        // Botón de alternancia de tema
        themeToggleButton.backgroundColor = Theme.Colors.surface
        themeToggleButton.layer.borderColor = Theme.Colors.border.cgColor
        themeToggleButton.setTitle(Theme.isDark ? "☀️" : "🌙", for: .normal)
        Theme.Shadows.applyButtonShadow(to: themeToggleButton.layer)

        // Botones y D-Pad
        dpadView.applyTheme()
        backButton.applyTheme()
        playPauseButton.applyTheme()
        homeButton.applyTheme()

        setNeedsStatusBarAppearanceUpdate()
    }

    @objc private func didTapThemeToggle() {
        HapticManager.playTactileClick()
        Theme.toggleTheme()
        
        UIView.animate(withDuration: 0.25) {
            self.applyTheme()
            self.updateStatusUI(self.client.currentStatus)
        }
    }

    // MARK: - Acciones y Conexiones

    private func setupActions() {
        pickerContainer.addTarget(self, action: #selector(didTapDevicePicker), for: .touchUpInside)
        themeToggleButton.addTarget(self, action: #selector(didTapThemeToggle), for: .touchUpInside)
        powerButton.addTarget(self, action: #selector(didTapPower), for: .touchUpInside)

        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(didTapHome), for: .touchUpInside)
    }

    // MARK: - DPad Delegate
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

    // MARK: - Selector de Dispositivos (Bottom Sheet)
    @objc private func didTapDevicePicker() {
        HapticManager.playTactileClick()

        let sheet = DevicePickerSheet()
        sheet.modalPresentationStyle = .overCurrentContext
        sheet.modalTransitionStyle = .crossDissolve
        sheet.delegate = self
        sheet.devices = discovery.devices

        if discovery.devices.isEmpty {
            discovery.startDiscovery()
        }

        present(sheet, animated: true)
    }

    // MARK: - DevicePickerDelegate
    func devicePickerDidSelectDevice(_ picker: DevicePickerSheet, device: DiscoveredTV) {
        client.connect(to: device)
    }

    // MARK: - Client Delegate & Estado
    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus) {
        updateStatusUI(status)

        if case .pairingRequired(let name) = status {
            showPairingDialog(for: name)
        }
    }

    private func updateStatusUI(_ status: ConnectionStatus) {
        switch status {
        case .disconnected:
            tvNameLabel.text = client.currentTVName ?? "Seleccionar TV"
            statusDot.backgroundColor = Theme.Colors.disconnected
            statusSubtitleLabel.text = "Desconectado"
            statusSubtitleLabel.textColor = Theme.Colors.textSecondary

        case .searching:
            tvNameLabel.text = client.currentTVName ?? "Buscando TV…"
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = "Buscando en red…"
            statusSubtitleLabel.textColor = Theme.Colors.accent

        case .ready(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.connected
            statusSubtitleLabel.text = "Conectado"
            statusSubtitleLabel.textColor = Theme.Colors.connected

        case .connecting(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = "Conectando…"
            statusSubtitleLabel.textColor = Theme.Colors.accent

        case .pairingRequired(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.accent
            statusSubtitleLabel.text = "Ingresar PIN en pantalla"
            statusSubtitleLabel.textColor = Theme.Colors.accent

        case .connected(let name):
            tvNameLabel.text = name
            statusDot.backgroundColor = Theme.Colors.connected
            statusSubtitleLabel.text = "Conectado"
            statusSubtitleLabel.textColor = Theme.Colors.connected

        case .error(let msg):
            tvNameLabel.text = client.currentTVName ?? "Error"
            statusDot.backgroundColor = Theme.Colors.disconnected
            statusSubtitleLabel.text = msg
            statusSubtitleLabel.textColor = Theme.Colors.textSecondary
        }
    }

    private func showPairingDialog(for name: String) {
        let alert = UIAlertController(
            title: "Código en pantalla",
            message: "Introduce el código PIN que aparece en tu \(name):",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Código (ej. AB12CD)"
            tf.autocapitalizationType = .allCharacters
            tf.textAlignment = .center
            tf.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        }
        alert.addAction(UIAlertAction(title: "Emparejar", style: .default, handler: { [weak self] _ in
            if let pin = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !pin.isEmpty {
                self?.client.submitPin(pin)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }
}
