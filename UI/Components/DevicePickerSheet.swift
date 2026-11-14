// DevicePickerSheet.swift — Modal bottom sheet for TV discovery matching Stitch second version design
// Fully compliant with Swift 5.0 and iOS 12.0+ (100% programmatic UIKit, vector CoreGraphics)

import UIKit

// MARK: - DevicePickerDelegate

protocol DevicePickerDelegate: AnyObject {
    func devicePickerDidSelectDevice(_ picker: DevicePickerSheet, device: DiscoveredTV)
    func devicePickerDidRequestScanAgain(_ picker: DevicePickerSheet)
    func devicePickerDidRequestManualIP(_ picker: DevicePickerSheet, host: String)
}

extension DevicePickerDelegate {
    func devicePickerDidRequestScanAgain(_ picker: DevicePickerSheet) {}
    func devicePickerDidRequestManualIP(_ picker: DevicePickerSheet, host: String) {}
}

// MARK: - DevicePickerSheet

class DevicePickerSheet: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    weak var delegate: DevicePickerDelegate?

    var currentConnectedHost: String?

    var devices: [DiscoveredTV] = [] {
        didSet {
            updateViewState()
        }
    }

    var isScanning: Bool = true {
        didSet {
            updateHeaderStatus()
        }
    }

    // MARK: - Subviews & Layout Constraints

    private let backdropView = UIView()
    private let containerView = UIView()
    private let grabberPill = UIView()

    // Header Components
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusDotView = UIView()
    private let activitySpinner = UIActivityIndicatorView(style: .white)
    private let closeButton = UIButton(type: .custom)

    // Content Views
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateScrollView = UIScrollView()
    private let emptyStateContainer = UIView()

    // Empty State Hero
    private let emptyHeroCircle = EmptyStateHeroView()
    private let emptyTitleLabel = UILabel()
    private let emptyDescLabel = UILabel()

    // Troubleshooting Diagnostic Card
    private let diagnosticCardView = UIView()
    private let diagnosticHeaderLabel = UILabel()
    private let tipWifiRow = TroubleshootingTipRow(tipType: .wifi)
    private let tipPermissionRow = TroubleshootingTipRow(tipType: .permission)
    private let tipPowerRow = TroubleshootingTipRow(tipType: .power)

    // Bottom Action Buttons
    private let actionsContainer = UIView()
    private let scanAgainButton = PrimaryActionButton()
    private let manualIPButton = SecondaryActionButton()

    // Bottom Sheet Constraints
    private var containerBottomConstraint: NSLayoutConstraint?
    private var containerHeightConstraint: NSLayoutConstraint?
    private var isDismissing: Bool = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupGestureRecognizers()
        setupNotifications()
        updateViewState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatePresentation()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: Theme.themeDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDiscoveryUpdated(_:)),
            name: NSNotification.Name("GoogleTVDiscoveryDidUpdateDevicesNotification"),
            object: nil
        )
    }

    @objc private func handleThemeChanged() {
        applyTheme()
    }

    @objc private func handleDiscoveryUpdated(_ notification: Notification) {
        if let updatedDevices = notification.object as? [DiscoveredTV] {
            self.devices = updatedDevices
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

        // 3. Grabber Pill
        grabberPill.translatesAutoresizingMaskIntoConstraints = false
        grabberPill.layer.cornerRadius = 2.5
        containerView.addSubview(grabberPill)

        // 4. Header Labels & Controls
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.85
        containerView.addSubview(titleLabel)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.layer.cornerRadius = 9.0
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        containerView.addSubview(badgeLabel)

        statusDotView.translatesAutoresizingMaskIntoConstraints = false
        statusDotView.layer.cornerRadius = 3.5
        containerView.addSubview(statusDotView)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        containerView.addSubview(subtitleLabel)

        activitySpinner.translatesAutoresizingMaskIntoConstraints = false
        activitySpinner.hidesWhenStopped = true
        containerView.addSubview(activitySpinner)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.layer.cornerRadius = 15.0
        closeButton.layer.borderWidth = 1.0
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        containerView.addSubview(closeButton)

        // 5. TableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DevicePickerTVCell.self, forCellReuseIdentifier: DevicePickerTVCell.reuseIdentifier)
        containerView.addSubview(tableView)

        // 6. Empty State Scrollable Container
        emptyStateScrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateScrollView.backgroundColor = .clear
        emptyStateScrollView.showsVerticalScrollIndicator = false
        containerView.addSubview(emptyStateScrollView)

        emptyStateContainer.translatesAutoresizingMaskIntoConstraints = false
        emptyStateContainer.backgroundColor = .clear
        emptyStateScrollView.addSubview(emptyStateContainer)

        emptyHeroCircle.translatesAutoresizingMaskIntoConstraints = false
        emptyStateContainer.addSubview(emptyHeroCircle)

        emptyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        emptyTitleLabel.textAlignment = .center
        emptyTitleLabel.text = L10n.Picker.emptyTitle
        emptyStateContainer.addSubview(emptyTitleLabel)

        emptyDescLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyDescLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        emptyDescLabel.textAlignment = .center
        emptyDescLabel.numberOfLines = 0
        emptyDescLabel.text = L10n.Picker.emptyDescription
        emptyStateContainer.addSubview(emptyDescLabel)

        // 7. Diagnostic Troubleshooting Card
        diagnosticCardView.translatesAutoresizingMaskIntoConstraints = false
        diagnosticCardView.layer.cornerRadius = 16.0
        diagnosticCardView.layer.borderWidth = 1.0
        emptyStateContainer.addSubview(diagnosticCardView)

        diagnosticHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        diagnosticHeaderLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        diagnosticHeaderLabel.text = L10n.Picker.troubleshootingTitle.uppercased()
        diagnosticCardView.addSubview(diagnosticHeaderLabel)

        tipWifiRow.translatesAutoresizingMaskIntoConstraints = false
        diagnosticCardView.addSubview(tipWifiRow)

        tipPermissionRow.translatesAutoresizingMaskIntoConstraints = false
        diagnosticCardView.addSubview(tipPermissionRow)

        tipPowerRow.translatesAutoresizingMaskIntoConstraints = false
        diagnosticCardView.addSubview(tipPowerRow)

        // 8. Bottom Action Buttons
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(actionsContainer)

        scanAgainButton.translatesAutoresizingMaskIntoConstraints = false
        scanAgainButton.addTarget(self, action: #selector(didTapScanAgain), for: .touchUpInside)
        actionsContainer.addSubview(scanAgainButton)

        manualIPButton.translatesAutoresizingMaskIntoConstraints = false
        manualIPButton.addTarget(self, action: #selector(didTapManualIP), for: .touchUpInside)
        actionsContainer.addSubview(manualIPButton)

        // Activate Auto Layout Constraints
        let screenHeight = UIScreen.main.bounds.height
        let maxHeight = min(screenHeight * 0.86, 620.0)

        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 650)
        containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: maxHeight)

        NSLayoutConstraint.activate([
            // Backdrop
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Container Sheet
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint!,
            containerHeightConstraint!,

            // Grabber
            grabberPill.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            grabberPill.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            grabberPill.widthAnchor.constraint(equalToConstant: 40),
            grabberPill.heightAnchor.constraint(equalToConstant: 5),

            // Header Title & Badge
            titleLabel.topAnchor.constraint(equalTo: grabberPill.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),

            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            // Header Status & Subtitle
            statusDotView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusDotView.centerYAnchor.constraint(equalTo: subtitleLabel.centerYAnchor),
            statusDotView.widthAnchor.constraint(equalToConstant: 7),
            statusDotView.heightAnchor.constraint(equalToConstant: 7),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: statusDotView.trailingAnchor, constant: 6),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            // Header Close / Spinner
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            activitySpinner.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            activitySpinner.centerXAnchor.constraint(equalTo: closeButton.centerXAnchor),

            // TableView
            tableView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: actionsContainer.topAnchor, constant: -10),

            // Empty State ScrollView
            emptyStateScrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),
            emptyStateScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            emptyStateScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            emptyStateScrollView.bottomAnchor.constraint(equalTo: actionsContainer.topAnchor, constant: -10),

            emptyStateContainer.topAnchor.constraint(equalTo: emptyStateScrollView.topAnchor),
            emptyStateContainer.leadingAnchor.constraint(equalTo: emptyStateScrollView.leadingAnchor),
            emptyStateContainer.trailingAnchor.constraint(equalTo: emptyStateScrollView.trailingAnchor),
            emptyStateContainer.bottomAnchor.constraint(equalTo: emptyStateScrollView.bottomAnchor),
            emptyStateContainer.widthAnchor.constraint(equalTo: emptyStateScrollView.widthAnchor),

            // Empty State Hero
            emptyHeroCircle.topAnchor.constraint(equalTo: emptyStateContainer.topAnchor, constant: 10),
            emptyHeroCircle.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyHeroCircle.widthAnchor.constraint(equalToConstant: 76),
            emptyHeroCircle.heightAnchor.constraint(equalToConstant: 76),

            emptyTitleLabel.topAnchor.constraint(equalTo: emptyHeroCircle.bottomAnchor, constant: 12),
            emptyTitleLabel.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor, constant: 20),
            emptyTitleLabel.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor, constant: -20),

            emptyDescLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: 6),
            emptyDescLabel.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor, constant: 28),
            emptyDescLabel.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor, constant: -28),

            // Diagnostic Card
            diagnosticCardView.topAnchor.constraint(equalTo: emptyDescLabel.bottomAnchor, constant: 14),
            diagnosticCardView.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor, constant: 18),
            diagnosticCardView.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor, constant: -18),
            diagnosticCardView.bottomAnchor.constraint(equalTo: emptyStateContainer.bottomAnchor, constant: -10),

            diagnosticHeaderLabel.topAnchor.constraint(equalTo: diagnosticCardView.topAnchor, constant: 12),
            diagnosticHeaderLabel.leadingAnchor.constraint(equalTo: diagnosticCardView.leadingAnchor, constant: 14),
            diagnosticHeaderLabel.trailingAnchor.constraint(equalTo: diagnosticCardView.trailingAnchor, constant: -14),

            tipWifiRow.topAnchor.constraint(equalTo: diagnosticHeaderLabel.bottomAnchor, constant: 10),
            tipWifiRow.leadingAnchor.constraint(equalTo: diagnosticCardView.leadingAnchor, constant: 12),
            tipWifiRow.trailingAnchor.constraint(equalTo: diagnosticCardView.trailingAnchor, constant: -12),

            tipPermissionRow.topAnchor.constraint(equalTo: tipWifiRow.bottomAnchor, constant: 8),
            tipPermissionRow.leadingAnchor.constraint(equalTo: diagnosticCardView.leadingAnchor, constant: 12),
            tipPermissionRow.trailingAnchor.constraint(equalTo: diagnosticCardView.trailingAnchor, constant: -12),

            tipPowerRow.topAnchor.constraint(equalTo: tipPermissionRow.bottomAnchor, constant: 8),
            tipPowerRow.leadingAnchor.constraint(equalTo: diagnosticCardView.leadingAnchor, constant: 12),
            tipPowerRow.trailingAnchor.constraint(equalTo: diagnosticCardView.trailingAnchor, constant: -12),
            tipPowerRow.bottomAnchor.constraint(equalTo: diagnosticCardView.bottomAnchor, constant: -12),

            // Bottom Actions Container
            actionsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            actionsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            actionsContainer.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            scanAgainButton.topAnchor.constraint(equalTo: actionsContainer.topAnchor),
            scanAgainButton.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),
            scanAgainButton.trailingAnchor.constraint(equalTo: actionsContainer.trailingAnchor),
            scanAgainButton.heightAnchor.constraint(equalToConstant: 46),

            manualIPButton.topAnchor.constraint(equalTo: scanAgainButton.bottomAnchor, constant: 8),
            manualIPButton.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),
            manualIPButton.trailingAnchor.constraint(equalTo: actionsContainer.trailingAnchor),
            manualIPButton.heightAnchor.constraint(equalToConstant: 38),
            manualIPButton.bottomAnchor.constraint(equalTo: actionsContainer.bottomAnchor)
        ])
    }

    // MARK: - Gesture Recognizers & Interactive Dismiss

    private func setupGestureRecognizers() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapBackdrop))
        tap.cancelsTouchesInView = false
        backdropView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        pan.delegate = self
        containerView.addGestureRecognizer(pan)
    }

    @objc private func didTapBackdrop() {
        dismissAnimated()
    }

    @objc private func didTapClose() {
        HapticManager.playTactileClick()
        dismissAnimated()
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                containerBottomConstraint?.constant = translation.y
                let progress = min(translation.y / 300.0, 1.0)
                backdropView.alpha = 1.0 - (progress * 0.7)
                view.layoutIfNeeded()
            }
        case .ended, .cancelled:
            if translation.y > 140 || velocity.y > 700 {
                dismissAnimated()
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: { [weak self] in
                    self?.containerBottomConstraint?.constant = 0
                    self?.backdropView.alpha = 1.0
                    self?.view.layoutIfNeeded()
                })
            }
        default:
            break
        }
    }

    // MARK: - Presentation & Dismissal Animations

    private func animatePresentation() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.6, options: [.curveEaseOut], animations: { [weak self] in
            guard let self = self else { return }
            self.backdropView.backgroundColor = Theme.Colors.sheetBackdrop
            self.containerBottomConstraint?.constant = 0
            self.view.layoutIfNeeded()
        })
    }

    func dismissAnimated(completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn], animations: { [weak self] in
            guard let self = self else { return }
            self.backdropView.backgroundColor = .clear
            self.containerBottomConstraint?.constant = self.containerView.bounds.height + 60
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: completion)
        })
    }

    // MARK: - View State & Theme

    private func updateViewState() {
        let hasDevices = !devices.isEmpty
        tableView.isHidden = !hasDevices
        emptyStateScrollView.isHidden = hasDevices

        titleLabel.text = L10n.Picker.title

        if hasDevices {
            badgeLabel.text = "  \(L10n.Picker.wifiBadge)  "
            badgeLabel.backgroundColor = Theme.Colors.badgeWifiBackground
            badgeLabel.textColor = Theme.Colors.badgeWifiText
            scanAgainButton.setTitle(L10n.Picker.scanAgain, for: .normal)
            tableView.reloadData()
        } else {
            badgeLabel.text = "  \(L10n.Picker.detectedCount(0))  "
            badgeLabel.backgroundColor = Theme.isDark ? UIColor(white: 1.0, alpha: 0.08) : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)
            badgeLabel.textColor = Theme.Colors.textSecondary
            scanAgainButton.setTitle(L10n.Picker.retrySearch, for: .normal)
        }

        updateHeaderStatus()
    }

    private func updateHeaderStatus() {
        if isScanning {
            statusDotView.backgroundColor = Theme.Colors.connected
            subtitleLabel.text = "\(L10n.Picker.scanningLocalNetwork) • \(L10n.Picker.activeSearch)"
            activitySpinner.startAnimating()
            closeButton.isHidden = true
        } else {
            statusDotView.backgroundColor = Theme.Colors.sunYellow
            subtitleLabel.text = "\(L10n.Picker.scanningLocalNetwork) • \(L10n.Picker.searchCompleted)"
            activitySpinner.stopAnimating()
            closeButton.isHidden = false
        }
    }

    private func applyTheme() {
        containerView.backgroundColor = Theme.Colors.sheetBackground
        containerView.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        containerView.layer.borderWidth = 1.0

        grabberPill.backgroundColor = Theme.Colors.sheetGrabber

        titleLabel.textColor = Theme.Colors.textPrimary
        subtitleLabel.textColor = Theme.Colors.textSecondary

        closeButton.backgroundColor = Theme.isDark ? UIColor(white: 1.0, alpha: 0.08) : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)
        closeButton.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        closeButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)

        activitySpinner.style = Theme.isDark ? .white : .gray

        emptyTitleLabel.textColor = Theme.Colors.textPrimary
        emptyDescLabel.textColor = Theme.Colors.textSecondary

        diagnosticCardView.backgroundColor = Theme.Colors.sheetCardBackground
        diagnosticCardView.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        diagnosticHeaderLabel.textColor = Theme.Colors.textSecondary

        tipWifiRow.applyTheme()
        tipPermissionRow.applyTheme()
        tipPowerRow.applyTheme()

        emptyHeroCircle.applyTheme()
        manualIPButton.applyTheme()
        scanAgainButton.applyTheme()

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func didTapScanAgain() {
        HapticManager.playSelection()
        isScanning = true
        delegate?.devicePickerDidRequestScanAgain(self)
    }

    @objc private func didTapManualIP() {
        HapticManager.playSelection()
        presentManualIPAlert()
    }

    private func presentManualIPAlert() {
        let alert = UIAlertController(
            title: L10n.Picker.manualIpTitle,
            message: L10n.Picker.manualIpMessage,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = L10n.Picker.manualIpPlaceholder
            textField.keyboardType = .numbersAndPunctuation
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.text = AppConstants.Network.targetDeviceFallbackIP
        }

        let connectAction = UIAlertAction(title: L10n.Picker.manualIpConnect, style: .default) { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }

            let customTV = DiscoveredTV(
                name: "Android TV (\(text))",
                host: text,
                port: AppConstants.Network.remoteControlPort
            )

            self.delegate?.devicePickerDidRequestManualIP(self, host: text)
            self.delegate?.devicePickerDidSelectDevice(self, device: customTV)
            self.dismissAnimated()
        }

        let cancelAction = UIAlertAction(title: L10n.Common.cancel, style: .cancel, handler: nil)

        alert.addAction(connectAction)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 74.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DevicePickerTVCell.reuseIdentifier, for: indexPath) as? DevicePickerTVCell else {
            return UITableViewCell()
        }

        let device = devices[indexPath.row]
        let isConnected = (device.host == currentConnectedHost) || (currentConnectedHost == nil && indexPath.row == 0)
        cell.configure(with: device, isConnected: isConnected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticManager.playSelection()
        let selectedDevice = devices[indexPath.row]
        delegate?.devicePickerDidSelectDevice(self, device: selectedDevice)
        dismissAnimated()
    }
}

// MARK: - DevicePickerTVCell

private class DevicePickerTVCell: UITableViewCell {

    static let reuseIdentifier = "DevicePickerTVCell"

    private let cardView = UIView()
    private let tvIconBadge = TVIconBadgeView()
    private let nameLabel = UILabel()
    private let activePillLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let trailingCheckmarkView = CircularCheckmarkView()
    private let trailingChevronView = ChevronRightView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 16.0
        cardView.layer.borderWidth = 1.0
        contentView.addSubview(cardView)

        tvIconBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(tvIconBadge)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        cardView.addSubview(nameLabel)

        activePillLabel.translatesAutoresizingMaskIntoConstraints = false
        activePillLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        activePillLabel.text = " \(L10n.Picker.currentBadge) "
        activePillLabel.layer.cornerRadius = 4.0
        activePillLabel.clipsToBounds = true
        cardView.addSubview(activePillLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        cardView.addSubview(subtitleLabel)

        trailingCheckmarkView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(trailingCheckmarkView)

        trailingChevronView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(trailingChevronView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            tvIconBadge.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            tvIconBadge.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            tvIconBadge.widthAnchor.constraint(equalToConstant: 44),
            tvIconBadge.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: tvIconBadge.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),

            activePillLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            activePillLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            activePillLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingCheckmarkView.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -40),

            trailingCheckmarkView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            trailingCheckmarkView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            trailingCheckmarkView.widthAnchor.constraint(equalToConstant: 26),
            trailingCheckmarkView.heightAnchor.constraint(equalToConstant: 26),

            trailingChevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            trailingChevronView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            trailingChevronView.widthAnchor.constraint(equalToConstant: 12),
            trailingChevronView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    func configure(with device: DiscoveredTV, isConnected: Bool) {
        nameLabel.text = device.name

        if isConnected {
            cardView.backgroundColor = Theme.Colors.sheetActiveCardBackground
            cardView.layer.borderColor = Theme.Colors.sheetActiveCardBorder.cgColor
            nameLabel.textColor = Theme.Colors.textPrimary

            activePillLabel.isHidden = false
            activePillLabel.backgroundColor = Theme.Colors.badgeCurrentBackground
            activePillLabel.textColor = Theme.Colors.badgeCurrentText

            subtitleLabel.text = "Google TV • \(device.host) • \(L10n.Picker.connectedStatus)"
            subtitleLabel.textColor = Theme.Colors.connected

            tvIconBadge.configure(isActive: true)
            trailingCheckmarkView.isHidden = false
            trailingChevronView.isHidden = true
        } else {
            cardView.backgroundColor = Theme.Colors.sheetCardBackground
            cardView.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
            nameLabel.textColor = Theme.Colors.textPrimary

            activePillLabel.isHidden = true

            subtitleLabel.text = "Android TV • \(device.host) • \(L10n.Picker.availableStatus)"
            subtitleLabel.textColor = Theme.Colors.textSecondary

            tvIconBadge.configure(isActive: false)
            trailingCheckmarkView.isHidden = true
            trailingChevronView.isHidden = false
        }
    }
}

// MARK: - TVIconBadgeView (Vector TV Screen + Indicator Dot)

private class TVIconBadgeView: UIView {

    private var isActive: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 12.0
        layer.borderWidth = 1.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isActive: Bool) {
        self.isActive = isActive
        if isActive {
            backgroundColor = Theme.isDark ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15) : UIColor(red: 220/255, green: 252/255, blue: 231/255, alpha: 0.8)
            layer.borderColor = Theme.Colors.sheetActiveCardBorder.cgColor
        } else {
            backgroundColor = Theme.isDark ? UIColor(white: 1.0, alpha: 0.05) : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)
            layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let iconColor: UIColor = isActive ? Theme.Colors.connected : Theme.Colors.textSecondary
        ctx.setFillColor(iconColor.cgColor)
        ctx.setStrokeColor(iconColor.cgColor)

        // TV Outer Screen Rect (20 x 14 pt centered)
        let screenRect = CGRect(x: rect.midX - 10, y: rect.midY - 8, width: 20, height: 13)
        let screenPath = UIBezierPath(roundedRect: screenRect, cornerRadius: 2.5)
        ctx.setLineWidth(1.6)
        screenPath.stroke()

        // TV Stand Leg & Base
        let standPath = UIBezierPath()
        standPath.move(to: CGPoint(x: rect.midX, y: screenRect.maxY))
        standPath.addLine(to: CGPoint(x: rect.midX, y: screenRect.maxY + 3))
        standPath.move(to: CGPoint(x: rect.midX - 4, y: screenRect.maxY + 3))
        standPath.addLine(to: CGPoint(x: rect.midX + 4, y: screenRect.maxY + 3))
        standPath.lineWidth = 1.6
        standPath.lineCapStyle = .round
        standPath.stroke()

        // Active Pulsing Dot at top-right corner
        if isActive {
            let dotRect = CGRect(x: rect.width - 9, y: 3, width: 6, height: 6)
            ctx.setFillColor(Theme.Colors.connected.cgColor)
            ctx.fillEllipse(in: dotRect)
        }
    }
}

// MARK: - CircularCheckmarkView

private class CircularCheckmarkView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Green Circle Fill
        let circleRect = rect.insetBy(dx: 1.0, dy: 1.0)
        ctx.setFillColor(Theme.Colors.connected.cgColor)
        ctx.fillEllipse(in: circleRect)

        // Crisp White Checkmark
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2.4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let checkPath = UIBezierPath()
        checkPath.move(to: CGPoint(x: rect.midX - 5.5, y: rect.midY - 0.5))
        checkPath.addLine(to: CGPoint(x: rect.midX - 1.5, y: rect.midY + 3.8))
        checkPath.addLine(to: CGPoint(x: rect.midX + 5.5, y: rect.midY - 4.0))
        checkPath.stroke()
    }
}

// MARK: - ChevronRightView

private class ChevronRightView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.setStrokeColor(Theme.Colors.textSecondary.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX - 3, y: rect.midY - 5))
        path.addLine(to: CGPoint(x: rect.midX + 2.5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - 3, y: rect.midY + 5))
        path.stroke()
    }
}

// MARK: - EmptyStateHeroView (TV with diagonal slash and red warning dot)

private class EmptyStateHeroView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 38.0
        layer.borderWidth = 1.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        backgroundColor = Theme.isDark ? UIColor(red: 26/255, green: 31/255, blue: 45/255, alpha: 1.0) : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)
        layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // TV Frame (32 x 22 pt)
        let tvColor = Theme.Colors.textSecondary
        ctx.setStrokeColor(tvColor.cgColor)
        ctx.setLineWidth(2.2)

        let tvRect = CGRect(x: rect.midX - 16, y: rect.midY - 13, width: 32, height: 21)
        let tvPath = UIBezierPath(roundedRect: tvRect, cornerRadius: 4.0)
        tvPath.stroke()

        // TV Stand
        let stand = UIBezierPath()
        stand.move(to: CGPoint(x: rect.midX, y: tvRect.maxY))
        stand.addLine(to: CGPoint(x: rect.midX, y: tvRect.maxY + 4))
        stand.move(to: CGPoint(x: rect.midX - 6, y: tvRect.maxY + 4))
        stand.addLine(to: CGPoint(x: rect.midX + 6, y: tvRect.maxY + 4))
        stand.lineWidth = 2.0
        stand.lineCapStyle = .round
        stand.stroke()

        // Red Diagonal Slash
        ctx.setStrokeColor(Theme.Colors.alertRed.cgColor)
        ctx.setLineWidth(2.6)
        ctx.setLineCap(.round)

        let slash = UIBezierPath()
        slash.move(to: CGPoint(x: rect.midX - 19, y: rect.midY - 16))
        slash.addLine(to: CGPoint(x: rect.midX + 19, y: rect.midY + 16))
        slash.stroke()

        // Bottom right red alert badge
        let alertCircleRect = CGRect(x: rect.width - 22, y: rect.height - 22, width: 18, height: 18)
        ctx.setFillColor(Theme.Colors.alertRed.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: alertCircleRect)

        let alertDotRect = CGRect(x: rect.width - 17, y: rect.height - 17, width: 8, height: 8)
        ctx.setFillColor(Theme.Colors.alertRed.cgColor)
        ctx.fillEllipse(in: alertDotRect)
    }
}

// MARK: - TroubleshootingTipRow

private enum TroubleshootingTipType {
    case wifi
    case permission
    case power
}

private class TroubleshootingTipRow: UIView {

    private let tipType: TroubleshootingTipType
    private let iconBadge = TipIconBadgeView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()

    init(tipType: TroubleshootingTipType) {
        self.tipType = tipType
        super.init(frame: .zero)
        setupRow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupRow() {
        backgroundColor = .clear

        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.tipType = tipType
        addSubview(iconBadge)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        addSubview(titleLabel)

        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .regular)
        descLabel.numberOfLines = 0
        addSubview(descLabel)

        switch tipType {
        case .wifi:
            titleLabel.text = L10n.Picker.tipWifiTitle
            descLabel.text = L10n.Picker.tipWifiDesc
        case .permission:
            titleLabel.text = L10n.Picker.tipPermissionTitle
            descLabel.text = L10n.Picker.tipPermissionDesc
        case .power:
            titleLabel.text = L10n.Picker.tipPowerTitle
            descLabel.text = L10n.Picker.tipPowerDesc
        }

        NSLayoutConstraint.activate([
            iconBadge.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconBadge.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            iconBadge.widthAnchor.constraint(equalToConstant: 26),
            iconBadge.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),

            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func applyTheme() {
        titleLabel.textColor = Theme.Colors.textPrimary
        descLabel.textColor = Theme.Colors.textSecondary
        iconBadge.applyTheme()
    }
}

// MARK: - TipIconBadgeView (Vector Wi-Fi, Lock, or Power)

private class TipIconBadgeView: UIView {

    var tipType: TroubleshootingTipType = .wifi {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 7.0
        layer.borderWidth = 1.0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        switch tipType {
        case .wifi:
            backgroundColor = Theme.isDark ? UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 0.15) : UIColor(red: 219/255, green: 234/255, blue: 254/255, alpha: 0.8)
            layer.borderColor = Theme.Colors.badgeWifiText.withAlphaComponent(0.3).cgColor
        case .permission:
            backgroundColor = Theme.isDark ? UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.15) : UIColor(red: 254/255, green: 243/255, blue: 199/255, alpha: 0.8)
            layer.borderColor = Theme.Colors.sunYellow.withAlphaComponent(0.3).cgColor
        case .power:
            backgroundColor = Theme.isDark ? UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15) : UIColor(red: 220/255, green: 252/255, blue: 231/255, alpha: 0.8)
            layer.borderColor = Theme.Colors.connected.withAlphaComponent(0.3).cgColor
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        switch tipType {
        case .wifi:
            ctx.setStrokeColor(Theme.Colors.badgeWifiText.cgColor)
            ctx.setFillColor(Theme.Colors.badgeWifiText.cgColor)
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)

            // Outer arc
            let arc1 = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.midY + 5), radius: 8, startAngle: -.pi * 0.75, endAngle: -.pi * 0.25, clockwise: true)
            arc1.stroke()

            // Inner arc
            let arc2 = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.midY + 5), radius: 5, startAngle: -.pi * 0.75, endAngle: -.pi * 0.25, clockwise: true)
            arc2.stroke()

            // Dot
            ctx.fillEllipse(in: CGRect(x: rect.midX - 1.5, y: rect.midY + 3.5, width: 3, height: 3))

        case .permission:
            let lockColor = Theme.Colors.sunYellow
            ctx.setStrokeColor(lockColor.cgColor)
            ctx.setFillColor(lockColor.cgColor)
            ctx.setLineWidth(1.4)

            // Lock body
            let bodyRect = CGRect(x: rect.midX - 6, y: rect.midY - 1, width: 12, height: 9)
            let body = UIBezierPath(roundedRect: bodyRect, cornerRadius: 2.0)
            body.stroke()

            // Lock shackle
            let shackle = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.midY - 1), radius: 4, startAngle: .pi, endAngle: 0, clockwise: true)
            shackle.lineWidth = 1.4
            shackle.stroke()

        case .power:
            let pColor = Theme.Colors.connected
            ctx.setStrokeColor(pColor.cgColor)
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)

            // Power circle arc
            let arc = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: rect.midY + 1), radius: 6, startAngle: -.pi * 0.35, endAngle: -.pi * 0.65, clockwise: true)
            arc.stroke()

            // Power vertical line
            let line = UIBezierPath()
            line.move(to: CGPoint(x: rect.midX, y: rect.midY - 5))
            line.addLine(to: CGPoint(x: rect.midX, y: rect.midY + 1))
            line.lineWidth = 1.4
            line.stroke()
        }
    }
}

// MARK: - PrimaryActionButton (Scan Again / Retry)

private class PrimaryActionButton: UIButton {

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
        titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        setTitleColor(.white, for: .normal)
        addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        applyTheme()
    }

    func applyTheme() {
        backgroundColor = Theme.Colors.primaryButton
    }

    @objc private func handleTouchDown() {
        backgroundColor = Theme.Colors.primaryButtonPressed
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
    }

    @objc private func handleTouchUp() {
        backgroundColor = Theme.Colors.primaryButton
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
        }
    }
}

// MARK: - SecondaryActionButton (Manual IP)

private class SecondaryActionButton: UIButton {

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
        titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        setTitle(L10n.Picker.connectManualIP, for: .normal)
        applyTheme()
    }

    func applyTheme() {
        backgroundColor = Theme.isDark ? UIColor(white: 1.0, alpha: 0.05) : UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 0.8)
        layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        setTitleColor(Theme.Colors.textSecondary, for: .normal)
    }
}
