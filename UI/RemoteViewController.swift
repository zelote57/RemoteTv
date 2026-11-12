import UIKit

class RemoteViewController: UIViewController, DPadViewDelegate, GoogleTVClientDelegate, DevicePickerDelegate {

    // MARK: - Subviews
    private let headerView = UIView()
    private let statusPill = UIButton(type: .custom)
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let statusChevron = UILabel()
    private let powerButton = RemoteButton(title: "⏻", style: .power)
    
    private let dpadView = DPadView()
    
    // Fila de navegación central
    private let backButton = RemoteButton(title: "‹", style: .round)
    private let homeButton = RemoteButton(title: "⌂", style: .round)
    private let menuButton = RemoteButton(title: "≡", style: .round)
    
    // Fila inferior de controles (Volumen y Medios)
    private let volUpButton = RemoteButton(title: "VOL +", style: .pill)
    private let volDownButton = RemoteButton(title: "VOL −", style: .pill)
    private let muteButton = RemoteButton(title: "🔇", style: .round)
    private let playPauseButton = RemoteButton(title: "⏯", style: .round)

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
        
        // Iniciar búsqueda automática de televisores en la red local
        client.startAutoDiscovery()
    }

    private func setupLayout() {
        // 1. Barra Superior (Header)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        statusPill.backgroundColor = Theme.Colors.surface
        statusPill.layer.borderColor = Theme.Colors.border.cgColor
        statusPill.layer.borderWidth = 1.0
        statusPill.layer.cornerRadius = 18.0
        Theme.Shadows.applyButtonShadow(to: statusPill.layer)
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(statusPill)
        
        statusDot.layer.cornerRadius = 4.0
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusDot)
        
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = Theme.Colors.textPrimary
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusLabel)

        statusChevron.text = "▾"
        statusChevron.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusChevron.textColor = Theme.Colors.textSecondary
        statusChevron.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusChevron)
        
        powerButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(powerButton)
        
        // 2. D-Pad (Cruceta central)
        dpadView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dpadView)
        
        // 3. Fila de Navegación (Back, Home, Menu)
        let navStack = UIStackView(arrangedSubviews: [backButton, homeButton, menuButton])
        navStack.axis = .horizontal
        navStack.distribution = .equalSpacing
        navStack.alignment = .center
        navStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navStack)
        
        // 4. Panel Inferior (Volumen y Controles de Medios)
        let volStack = UIStackView(arrangedSubviews: [volUpButton, volDownButton])
        volStack.axis = .vertical
        volStack.spacing = 10
        volStack.distribution = .fillEqually
        volStack.translatesAutoresizingMaskIntoConstraints = false
        
        let actionsStack = UIStackView(arrangedSubviews: [muteButton, playPauseButton])
        actionsStack.axis = .horizontal
        actionsStack.spacing = 16
        actionsStack.distribution = .fillEqually
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let bottomContainer = UIStackView(arrangedSubviews: [volStack, actionsStack])
        bottomContainer.axis = .horizontal
        bottomContainer.distribution = .fillEqually
        bottomContainer.spacing = 24
        bottomContainer.alignment = .center
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)

        // Restricciones adaptadas tanto para iPhone 6 Plus (414x736 pt) como iPhone 6 normal
        let guide = view.safeAreaLayoutGuide
        let isPlusOrLarge = UIScreen.main.bounds.width >= 414
        let dpadDimension: CGFloat = isPlusOrLarge ? 230 : 210
        let buttonDimension: CGFloat = isPlusOrLarge ? 58 : 52
        
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Status Pill
            statusPill.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            statusPill.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 38),
            statusPill.trailingAnchor.constraint(lessThanOrEqualTo: powerButton.leadingAnchor, constant: -12),
            
            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 12),
            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),

            statusChevron.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 4),
            statusChevron.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -12),
            statusChevron.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            
            // Power Button
            powerButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            powerButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            powerButton.widthAnchor.constraint(equalToConstant: 44),
            powerButton.heightAnchor.constraint(equalToConstant: 44),
            
            // D-Pad
            dpadView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: isPlusOrLarge ? 35 : 20),
            dpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dpadView.widthAnchor.constraint(equalToConstant: dpadDimension),
            dpadView.heightAnchor.constraint(equalToConstant: dpadDimension),
            
            // Fila de Navegación
            navStack.topAnchor.constraint(equalTo: dpadView.bottomAnchor, constant: isPlusOrLarge ? 35 : 22),
            navStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: isPlusOrLarge ? 48 : 36),
            navStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: isPlusOrLarge ? -48 : -36),
            navStack.heightAnchor.constraint(equalToConstant: buttonDimension),
            
            backButton.widthAnchor.constraint(equalToConstant: buttonDimension),
            backButton.heightAnchor.constraint(equalToConstant: buttonDimension),
            homeButton.widthAnchor.constraint(equalToConstant: buttonDimension),
            homeButton.heightAnchor.constraint(equalToConstant: buttonDimension),
            menuButton.widthAnchor.constraint(equalToConstant: buttonDimension),
            menuButton.heightAnchor.constraint(equalToConstant: buttonDimension),
            
            // Contenedor inferior (Volumen y Medios)
            bottomContainer.topAnchor.constraint(equalTo: navStack.bottomAnchor, constant: isPlusOrLarge ? 35 : 22),
            bottomContainer.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: isPlusOrLarge ? 40 : 28),
            bottomContainer.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: isPlusOrLarge ? -40 : -28),
            bottomContainer.heightAnchor.constraint(equalToConstant: 114),
            
            muteButton.widthAnchor.constraint(equalToConstant: buttonDimension),
            muteButton.heightAnchor.constraint(equalToConstant: buttonDimension),
            playPauseButton.widthAnchor.constraint(equalToConstant: buttonDimension),
            playPauseButton.heightAnchor.constraint(equalToConstant: buttonDimension),
        ])
    }

    private func setupActions() {
        statusPill.addTarget(self, action: #selector(didTapStatusPill), for: .touchUpInside)
        powerButton.addTarget(self, action: #selector(didTapPower), for: .touchUpInside)
        
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(didTapHome), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        
        volUpButton.addTarget(self, action: #selector(didTapVolUp), for: .touchUpInside)
        volDownButton.addTarget(self, action: #selector(didTapVolDown), for: .touchUpInside)
        muteButton.addTarget(self, action: #selector(didTapMute), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(didTapPlayPause), for: .touchUpInside)
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
    @objc private func didTapMenu() { client.sendKey(.menu) }
    @objc private func didTapVolUp() { client.sendKey(.volumeUp) }
    @objc private func didTapVolDown() { client.sendKey(.volumeDown) }
    @objc private func didTapMute() { client.sendKey(.volumeMute) }
    @objc private func didTapPlayPause() { client.sendKey(.mediaPlayPause) }

    // MARK: - Selector de Dispositivos (Bottom Sheet)
    @objc private func didTapStatusPill() {
        HapticManager.playTactileClick()
        
        let sheet = DevicePickerSheet()
        sheet.modalPresentationStyle = .overCurrentContext
        sheet.modalTransitionStyle = .crossDissolve
        sheet.delegate = self
        sheet.devices = discovery.devices
        
        // Si la lista está vacía, forzamos un refresco de escaneo
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
            statusDot.backgroundColor = Theme.Colors.disconnected
            statusLabel.text = "Seleccionar TV"
        case .searching:
            statusDot.backgroundColor = Theme.Colors.accent
            statusLabel.text = "Buscando TV..."
        case .connecting(let name):
            statusDot.backgroundColor = Theme.Colors.accent
            statusLabel.text = "Conectando (\(name))..."
        case .pairingRequired:
            statusDot.backgroundColor = Theme.Colors.power
            statusLabel.text = "Ingresa PIN en TV"
        case .connected(let name):
            statusDot.backgroundColor = Theme.Colors.connected
            statusLabel.text = name
        case .error(let msg):
            statusDot.backgroundColor = Theme.Colors.power
            statusLabel.text = "Error: \(msg)"
        }
    }

    private func showPairingDialog(for name: String) {
        let alert = UIAlertController(
            title: "Código en pantalla",
            message: "Introduce el código PIN que aparece ahora mismo en tu \(name):",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Código (ej. AB12CD)"
            tf.autocapitalizationType = .allCharacters
            tf.textAlignment = .center
            tf.font = UIFont.systemFont(ofSize: 20, weight: .bold)
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
