// RemoteViewController.swift — Control Remoto Google TV
// Diseño Dark Minimalista idéntico a la guía visual de Google TV
// Optimizado para iPhone 6 Plus (iOS 12.0) sin letterboxing

import UIKit

class RemoteViewController: UIViewController, GoogleTVClientDelegate, DPadViewDelegate, DevicePickerDelegate {

    // MARK: - Componentes de Cabecera (Header)
    private let headerView = UIView()
    private let pickerContainer = UIControl()
    private let pickerChevronCircle = UIView()
    private let pickerChevronLabel = UILabel()
    private let tvNameLabel = UILabel()
    private let statusRow = UIStackView()
    private let statusDot = UIView()
    private let statusSubtitleLabel = UILabel()
    private let powerButton = PowerButton(type: .custom)

    // MARK: - D-Pad Central
    private let dpadView = DPadView()

    // MARK: - Panel Inferior (2x2 cuadrícula a la izquierda + Cápsula de volumen a la derecha)
    private let homeButton = RemoteButton(title: "⌂", style: .round)
    private let backButton = RemoteButton(title: "←", style: .round)
    private let inputButton = RemoteButton(title: "⇥", style: .round)
    private let muteButton = RemoteButton(title: "🔇", style: .round)
    private let volumeCapsule = VolumeCapsuleView()

    private let client = GoogleTVClient.shared
    private let discovery = GoogleTVDiscovery.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        
        client.delegate = self
        dpadView.delegate = self
        
        setupLayout()
        setupActions()
        updateStatusUI(client.currentStatus)
        
        client.startAutoDiscovery()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // Barra de estado en blanco para el tema oscuro
    }

    // MARK: - Layout Visual

    private func setupLayout() {
        let guide = view.safeAreaLayoutGuide

        // ══════════════════════════════════════════════════
        // 1. Cabecera (Header)
        // ══════════════════════════════════════════════════
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        // Contenedor táctil para selector de TV (Chevron + Nombre + Estado)
        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(pickerContainer)

        // Círculo del Chevron (ícono ▼)
        pickerChevronCircle.backgroundColor = Theme.Colors.surface
        pickerChevronCircle.layer.cornerRadius = 22.0
        pickerChevronCircle.layer.borderColor = Theme.Colors.border.cgColor
        pickerChevronCircle.layer.borderWidth = 1.0
        pickerChevronCircle.isUserInteractionEnabled = false
        pickerChevronCircle.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(pickerChevronCircle)

        pickerChevronLabel.text = "▼"
        pickerChevronLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        pickerChevronLabel.textColor = Theme.Colors.textPrimary
        pickerChevronLabel.textAlignment = .center
        pickerChevronLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerChevronCircle.addSubview(pickerChevronLabel)

        // Nombre del televisor
        tvNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        tvNameLabel.textColor = Theme.Colors.textPrimary
        tvNameLabel.isUserInteractionEnabled = false
        tvNameLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(tvNameLabel)

        // Fila de estado (Punto de color + Texto)
        statusDot.layer.cornerRadius = 3.5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        
        statusSubtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusSubtitleLabel.textColor = Theme.Colors.textSecondary
        statusSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusRow.axis = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .center
        statusRow.isUserInteractionEnabled = false
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusRow.addArrangedSubview(statusDot)
        statusRow.addArrangedSubview(statusSubtitleLabel)
        pickerContainer.addSubview(statusRow)

        // Botón Power (Verde con ícono IEC en CoreGraphics)
        powerButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(powerButton)

        // ══════════════════════════════════════════════════
        // 2. D-Pad Circular Central
        // ══════════════════════════════════════════════════
        dpadView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dpadView)

        // ══════════════════════════════════════════════════
        // 3. Panel Inferior Moderno (Guía Visual idéntica a la imagen)
        // ══════════════════════════════════════════════════
        // Cuadrícula izquierda: Fila 1 (Home, Back), Fila 2 (Input, Mute)
        let row1 = UIStackView(arrangedSubviews: [homeButton, backButton])
        row1.axis = .horizontal
        row1.spacing = 18
        row1.distribution = .fillEqually
        row1.translatesAutoresizingMaskIntoConstraints = false

        let row2 = UIStackView(arrangedSubviews: [inputButton, muteButton])
        row2.axis = .horizontal
        row2.spacing = 18
        row2.distribution = .fillEqually
        row2.translatesAutoresizingMaskIntoConstraints = false

        let leftControlsGrid = UIStackView(arrangedSubviews: [row1, row2])
        leftControlsGrid.axis = .vertical
        leftControlsGrid.spacing = 18
        leftControlsGrid.distribution = .fillEqually
        leftControlsGrid.translatesAutoresizingMaskIntoConstraints = false

        // Cápsula de volumen a la derecha
        volumeCapsule.translatesAutoresizingMaskIntoConstraints = false

        // Contenedor horizontal que agrupa (Izquierda: botones, Derecha: Cápsula Volumen)
        let bottomContainer = UIStackView(arrangedSubviews: [leftControlsGrid, volumeCapsule])
        bottomContainer.axis = .horizontal
        bottomContainer.spacing = 20
        bottomContainer.alignment = .center
        bottomContainer.distribution = .fill
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)

        // ══════════════════════════════════════════════════
        // Dimensiones calculadas para iPhone 6 Plus (414 x 736 pt)
        // ══════════════════════════════════════════════════
        let roundBtnSize: CGFloat = 66
        let dpadSize: CGFloat = 250
        let capsuleWidth: CGFloat = 74
        let capsuleHeight: CGFloat = (roundBtnSize * 2) + 18 // Altura exacta de las 2 filas = 150 pt

        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),
            headerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 48),

            // Selector de dispositivo
            pickerContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            pickerContainer.topAnchor.constraint(equalTo: headerView.topAnchor),
            pickerContainer.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            pickerContainer.trailingAnchor.constraint(lessThanOrEqualTo: powerButton.leadingAnchor, constant: -12),

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

            // Power
            powerButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            powerButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            powerButton.widthAnchor.constraint(equalToConstant: 46),
            powerButton.heightAnchor.constraint(equalToConstant: 46),

            // D-Pad Central
            dpadView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            dpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dpadView.widthAnchor.constraint(equalToConstant: dpadSize),
            dpadView.heightAnchor.constraint(equalToConstant: dpadSize),

            // Contenedor Inferior
            bottomContainer.topAnchor.constraint(equalTo: dpadView.bottomAnchor, constant: 36),
            bottomContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomContainer.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -20),

            // Tamaño de los botones redondos
            homeButton.widthAnchor.constraint(equalToConstant: roundBtnSize),
            homeButton.heightAnchor.constraint(equalToConstant: roundBtnSize),
            backButton.widthAnchor.constraint(equalToConstant: roundBtnSize),
            backButton.heightAnchor.constraint(equalToConstant: roundBtnSize),
            inputButton.widthAnchor.constraint(equalToConstant: roundBtnSize),
            inputButton.heightAnchor.constraint(equalToConstant: roundBtnSize),
            muteButton.widthAnchor.constraint(equalToConstant: roundBtnSize),
            muteButton.heightAnchor.constraint(equalToConstant: roundBtnSize),

            // Tamaño exacto de la cápsula de volumen
            volumeCapsule.widthAnchor.constraint(equalToConstant: capsuleWidth),
            volumeCapsule.heightAnchor.constraint(equalToConstant: capsuleHeight)
        ])
    }

    // MARK: - Acciones y Conexiones

    private func setupActions() {
        pickerContainer.addTarget(self, action: #selector(didTapDevicePicker), for: .touchUpInside)
        powerButton.addTarget(self, action: #selector(didTapPower), for: .touchUpInside)

        homeButton.addTarget(self, action: #selector(didTapHome), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        inputButton.addTarget(self, action: #selector(didTapInput), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(didTapMute), for: .touchUpInside)

        volumeCapsule.onVolumeUp = { [weak self] in
            self?.client.sendKey(.volumeUp)
        }
        volumeCapsule.onVolumeDown = { [weak self] in
            self?.client.sendKey(.volumeDown)
        }
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
    @objc private func didTapHome() { client.sendKey(.home) }
    @objc private func didTapInput() { client.sendKey(.tvInput) }
    @objc private func didTapMute() { client.sendKey(.volumeMute) }

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
