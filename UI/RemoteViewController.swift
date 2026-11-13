import UIKit

class RemoteViewController: UIViewController, DPadViewDelegate, GoogleTVClientDelegate, DevicePickerDelegate {

    // MARK: - Componentes de Cabecera
    private let headerView = UIView()
    private let statusPill = UIButton(type: .custom)
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let statusChevron = UILabel()
    private let powerButton = RemoteButton(title: "⏻", style: .power)
    
    // MARK: - D-Pad Central
    private let dpadView = DPadView()
    
    // MARK: - Fila de Navegación (Atrás, Inicio, Menú)
    private let backButton = RemoteButton(title: "‹", style: .round)
    private let homeButton = RemoteButton(title: "⌂", style: .round)
    private let menuButton = RemoteButton(title: "≡", style: .round)
    
    // MARK: - Panel Inferior Estilo Apple/Google TV Remote (Cápsulas Ergonómicas)
    private let volumeCapsule = UIView()
    private let volUpButton = UIButton(type: .custom)
    private let volDivider = UIView()
    private let volDownButton = UIButton(type: .custom)
    
    private let channelCapsule = UIView()
    private let chUpButton = UIButton(type: .custom)
    private let chDivider = UIView()
    private let chDownButton = UIButton(type: .custom)
    
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
        
        // Iniciar escaneo automático en segundo plano
        client.startAutoDiscovery()
    }

    private func setupLayout() {
        let guide = view.safeAreaLayoutGuide
        
        // 1. Barra Superior (Header)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        statusPill.backgroundColor = Theme.Colors.surface
        statusPill.layer.borderColor = Theme.Colors.border.cgColor
        statusPill.layer.borderWidth = 1.0
        statusPill.layer.cornerRadius = 21.0
        Theme.Shadows.applyButtonShadow(to: statusPill.layer)
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(statusPill)
        
        statusDot.layer.cornerRadius = 4.0
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusDot)
        
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        statusLabel.textColor = Theme.Colors.textPrimary
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusLabel)

        statusChevron.text = "▾"
        statusChevron.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        statusChevron.textColor = Theme.Colors.textSecondary
        statusChevron.translatesAutoresizingMaskIntoConstraints = false
        statusPill.addSubview(statusChevron)
        
        powerButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(powerButton)
        
        // 2. D-Pad Circular Central
        dpadView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dpadView)
        
        // 3. Fila de Navegación (Atrás, Inicio, Menú) - Botones Ampliados (64x64 pt)
        let navStack = UIStackView(arrangedSubviews: [backButton, homeButton, menuButton])
        navStack.axis = .horizontal
        navStack.distribution = .equalSpacing
        navStack.alignment = .center
        navStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navStack)
        
        // 4. Panel Inferior Moderno (Cápsula de Volumen + Centro Multimedia + Cápsula de Canales)
        setupCapsule(volumeCapsule, upBtn: volUpButton, divider: volDivider, downBtn: volDownButton, upTitle: "+", downTitle: "−")
        setupCapsule(channelCapsule, upBtn: chUpButton, divider: chDivider, downBtn: chDownButton, upTitle: "▲", downTitle: "▼")
        
        let centerActions = UIStackView(arrangedSubviews: [playPauseButton, muteButton])
        centerActions.axis = .vertical
        centerActions.spacing = 20
        centerActions.alignment = .center
        centerActions.distribution = .fillEqually
        centerActions.translatesAutoresizingMaskIntoConstraints = false

        let bottomControlsStack = UIStackView(arrangedSubviews: [volumeCapsule, centerActions, channelCapsule])
        bottomControlsStack.axis = .horizontal
        bottomControlsStack.distribution = .equalSpacing
        bottomControlsStack.alignment = .center
        bottomControlsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomControlsStack)

        // Restricciones AutoLayout amplias para la pantalla 5.5" de 414x736 pt del iPhone 6 Plus
        let navBtnSize: CGFloat = 64
        let dpadSize: CGFloat = 246
        let capsuleWidth: CGFloat = 70
        let capsuleHeight: CGFloat = 144
        let actionBtnSize: CGFloat = 58

        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),
            headerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            headerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            headerView.heightAnchor.constraint(equalToConstant: 48),
            
            // Píldora de Estado
            statusPill.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            statusPill.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 42),
            statusPill.trailingAnchor.constraint(lessThanOrEqualTo: powerButton.leadingAnchor, constant: -16),
            
            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 14),
            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 9),
            statusDot.heightAnchor.constraint(equalToConstant: 9),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 10),
            statusLabel.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),

            statusChevron.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 6),
            statusChevron.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -14),
            statusChevron.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            
            // Power Button
            powerButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            powerButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            powerButton.widthAnchor.constraint(equalToConstant: 46),
            powerButton.heightAnchor.constraint(equalToConstant: 46),
            
            // D-Pad Central
            dpadView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 28),
            dpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dpadView.widthAnchor.constraint(equalToConstant: dpadSize),
            dpadView.heightAnchor.constraint(equalToConstant: dpadSize),
            
            // Fila de Navegación
            navStack.topAnchor.constraint(equalTo: dpadView.bottomAnchor, constant: 28),
            navStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 44),
            navStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -44),
            navStack.heightAnchor.constraint(equalToConstant: navBtnSize),
            
            backButton.widthAnchor.constraint(equalToConstant: navBtnSize),
            backButton.heightAnchor.constraint(equalToConstant: navBtnSize),
            homeButton.widthAnchor.constraint(equalToConstant: navBtnSize),
            homeButton.heightAnchor.constraint(equalToConstant: navBtnSize),
            menuButton.widthAnchor.constraint(equalToConstant: navBtnSize),
            menuButton.heightAnchor.constraint(equalToConstant: navBtnSize),
            
            // Contenedor Inferior Moderno
            bottomControlsStack.topAnchor.constraint(equalTo: navStack.bottomAnchor, constant: 32),
            bottomControlsStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 36),
            bottomControlsStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -36),
            bottomControlsStack.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -18),
            
            volumeCapsule.widthAnchor.constraint(equalToConstant: capsuleWidth),
            volumeCapsule.heightAnchor.constraint(equalToConstant: capsuleHeight),
            
            channelCapsule.widthAnchor.constraint(equalToConstant: capsuleWidth),
            channelCapsule.heightAnchor.constraint(equalToConstant: capsuleHeight),
            
            muteButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            muteButton.heightAnchor.constraint(equalToConstant: actionBtnSize),
            playPauseButton.widthAnchor.constraint(equalToConstant: actionBtnSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: actionBtnSize),
        ])
    }

    private func setupCapsule(_ capsule: UIView, upBtn: UIButton, divider: UIView, downBtn: UIButton, upTitle: String, downTitle: String) {
        capsule.backgroundColor = Theme.Colors.surface
        capsule.layer.borderColor = Theme.Colors.border.cgColor
        capsule.layer.borderWidth = 1.0
        capsule.layer.cornerRadius = 35.0
        capsule.clipsToBounds = true
        Theme.Shadows.applyButtonShadow(to: capsule.layer)
        capsule.translatesAutoresizingMaskIntoConstraints = false

        upBtn.setTitle(upTitle, for: .normal)
        upBtn.setTitleColor(Theme.Colors.iconDark, for: .normal)
        upBtn.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        upBtn.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(upBtn)

        divider.backgroundColor = Theme.Colors.divider
        divider.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(divider)

        downBtn.setTitle(downTitle, for: .normal)
        downBtn.setTitleColor(Theme.Colors.iconDark, for: .normal)
        downBtn.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        downBtn.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(downBtn)

        NSLayoutConstraint.activate([
            upBtn.topAnchor.constraint(equalTo: capsule.topAnchor),
            upBtn.leadingAnchor.constraint(equalTo: capsule.leadingAnchor),
            upBtn.trailingAnchor.constraint(equalTo: capsule.trailingAnchor),
            upBtn.bottomAnchor.constraint(equalTo: divider.topAnchor),

            divider.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            divider.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -14),
            divider.heightAnchor.constraint(equalToConstant: 1),

            downBtn.topAnchor.constraint(equalTo: divider.bottomAnchor),
            downBtn.leadingAnchor.constraint(equalTo: capsule.leadingAnchor),
            downBtn.trailingAnchor.constraint(equalTo: capsule.trailingAnchor),
            downBtn.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
            downBtn.heightAnchor.constraint(equalTo: upBtn.heightAnchor)
        ])

        addTactileAction(to: upBtn)
        addTactileAction(to: downBtn)
    }

    private func addTactileAction(to btn: UIButton) {
        btn.addTarget(self, action: #selector(handleButtonPressDown(_:)), for: [.touchDown, .touchDragEnter])
        btn.addTarget(self, action: #selector(handleButtonPressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleButtonPressDown(_ sender: UIButton) {
        HapticManager.playTactileClick()
        UIView.animate(withDuration: 0.1) {
            sender.backgroundColor = Theme.Colors.surfacePressed
        }
    }

    @objc private func handleButtonPressUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2) {
            sender.backgroundColor = .clear
        }
    }

    private func setupActions() {
        statusPill.addTarget(self, action: #selector(didTapStatusPill), for: .touchUpInside)
        powerButton.addTarget(self, action: #selector(didTapPower), for: .touchUpInside)
        
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(didTapHome), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        
        volUpButton.addTarget(self, action: #selector(didTapVolUp), for: .touchUpInside)
        volDownButton.addTarget(self, action: #selector(didTapVolDown), for: .touchUpInside)
        chUpButton.addTarget(self, action: #selector(didTapChUp), for: .touchUpInside)
        chDownButton.addTarget(self, action: #selector(didTapChDown), for: .touchUpInside)
        
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
    @objc private func didTapChUp() { client.sendKey(.channelUp) }
    @objc private func didTapChDown() { client.sendKey(.channelDown) }
    @objc private func didTapMute() { client.sendKey(.volumeMute) }
    @objc private func didTapPlayPause() { client.sendKey(.mediaPlayPause) }

    // MARK: - Selector de Dispositivos (Bottom Sheet)
    @objc private func didTapStatusPill() {
        HapticManager.playTactileClick()
        
        // Si ya hay un TV detectado y listo, conectar de inmediato al tocar la píldora
        if case .ready(let name) = client.currentStatus, let host = client.currentHost {
            client.connect(to: DiscoveredTV(name: name, host: host, port: 6466))
            return
        }
        
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
            statusDot.backgroundColor = Theme.Colors.disconnected
            statusLabel.text = "Seleccionar TV"
        case .searching:
            statusDot.backgroundColor = Theme.Colors.accent
            statusLabel.text = "Buscando TV..."
        case .ready(let name):
            statusDot.backgroundColor = Theme.Colors.connected
            statusLabel.text = name
        case .connecting(let name):
            statusDot.backgroundColor = Theme.Colors.accent
            statusLabel.text = "Conectando (\(name))..."
        case .pairingRequired:
            statusDot.backgroundColor = Theme.Colors.power
            statusLabel.text = "Ingresar PIN en TV"
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
