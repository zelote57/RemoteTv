import UIKit

class RemoteViewController: UIViewController, DPadViewDelegate, GoogleTVClientDelegate {

    // MARK: - Subviews
    private let headerView = UIView()
    private let statusPill = UIButton(type: .custom)
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let powerButton = RemoteButton(title: "⏻", style: .power)
    
    private let dpadView = DPadView()
    
    // Fila de navegación central
    private let backButton = RemoteButton(title: "‹", style: .round)
    private let homeButton = RemoteButton(title: "⌂", style: .round)
    private let menuButton = RemoteButton(title: "≡", style: .round)
    
    // Fila inferior de controles (Volumen y Canales)
    private let volUpButton = RemoteButton(title: "VOL +", style: .pill)
    private let volDownButton = RemoteButton(title: "VOL −", style: .pill)
    private let muteButton = RemoteButton(title: "MUTE", style: .round)
    
    private let playPauseButton = RemoteButton(title: "⏯", style: .round)

    private let client = GoogleTVClient.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        
        client.delegate = self
        dpadView.delegate = self
        
        setupLayout()
        setupActions()
        updateStatusUI(client.currentStatus)
        
        // Si hay una IP guardada, intentamos reconectar automáticamente
        if let savedHost = client.getSavedHost() {
            client.connect(to: savedHost)
        }
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
        
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = Theme.Colors.textPrimary
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusLabel)
        
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
        bottomContainer.spacing = 20
        bottomContainer.alignment = .center
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)

        // Restricciones AutoLayout (Optimizadas para pantalla de iPhone 6 / 375x667 pt)
        let guide = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 10),
            headerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Status Pill
            statusPill.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            statusPill.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 36),
            statusPill.trailingAnchor.constraint(lessThanOrEqualTo: powerButton.leadingAnchor, constant: -12),
            
            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 12),
            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -14),
            statusLabel.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            
            // Power Button
            powerButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            powerButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            powerButton.widthAnchor.constraint(equalToConstant: 44),
            powerButton.heightAnchor.constraint(equalToConstant: 44),
            
            // D-Pad
            dpadView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 25),
            dpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dpadView.widthAnchor.constraint(equalToConstant: 220),
            dpadView.heightAnchor.constraint(equalToConstant: 220),
            
            // Fila de Navegación
            navStack.topAnchor.constraint(equalTo: dpadView.bottomAnchor, constant: 25),
            navStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 40),
            navStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -40),
            navStack.heightAnchor.constraint(equalToConstant: 54),
            
            backButton.widthAnchor.constraint(equalToConstant: 54),
            backButton.heightAnchor.constraint(equalToConstant: 54),
            homeButton.widthAnchor.constraint(equalToConstant: 54),
            homeButton.heightAnchor.constraint(equalToConstant: 54),
            menuButton.widthAnchor.constraint(equalToConstant: 54),
            menuButton.heightAnchor.constraint(equalToConstant: 54),
            
            // Contenedor inferior
            bottomContainer.topAnchor.constraint(equalTo: navStack.bottomAnchor, constant: 25),
            bottomContainer.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            bottomContainer.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32),
            bottomContainer.heightAnchor.constraint(equalToConstant: 110),
            
            muteButton.widthAnchor.constraint(equalToConstant: 52),
            muteButton.heightAnchor.constraint(equalToConstant: 52),
            playPauseButton.widthAnchor.constraint(equalToConstant: 52),
            playPauseButton.heightAnchor.constraint(equalToConstant: 52),
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

    // MARK: - Configuración de IP / Conexión
    @objc private func didTapStatusPill() {
        let alert = UIAlertController(
            title: "Conectar a Google TV",
            message: "Introduce la dirección IP de tu televisor (ej. 192.168.1.50):",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "192.168.1.X"
            textField.keyboardType = .numbersAndPunctuation
            textField.text = self.client.getSavedHost()
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Conectar", style: .default, handler: { [weak self] _ in
            if let ip = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty {
                self?.client.connect(to: ip)
            }
        }))
        
        present(alert, animated: true)
    }

    // MARK: - Client Delegate & Estado
    func clientDidChangeStatus(_ client: GoogleTVClient, status: ConnectionStatus) {
        updateStatusUI(status)
        
        if case .pairingRequired(let host) = status {
            showPairingDialog(for: host)
        }
    }

    private func updateStatusUI(_ status: ConnectionStatus) {
        switch status {
        case .disconnected:
            statusDot.backgroundColor = Theme.Colors.disconnected
            statusLabel.text = "Desconectado"
        case .connecting(let host):
            statusDot.backgroundColor = Theme.Colors.accent
            statusLabel.text = "Conectando (\(host))..."
        case .pairingRequired:
            statusDot.backgroundColor = Theme.Colors.power
            statusLabel.text = "Ingresa PIN en TV"
        case .connected(let host):
            statusDot.backgroundColor = Theme.Colors.connected
            statusLabel.text = "Google TV (\(host))"
        case .error(let msg):
            statusDot.backgroundColor = Theme.Colors.power
            statusLabel.text = "Error: \(msg)"
        }
    }

    private func showPairingDialog(for host: String) {
        let alert = UIAlertController(
            title: "Código de Emparejamiento",
            message: "Introduce el código PIN que aparece en la pantalla de tu TV:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Código (ej. AB12CD)"
            tf.autocapitalizationType = .allCharacters
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
