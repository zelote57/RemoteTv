// SettingsSheet.swift — Modal bottom sheet for Language selection and App/Developer information
// Fully compliant with Swift 5.0 and iOS 12.0+ (100% programmatic UIKit, vector CoreGraphics)

import UIKit

// MARK: - SettingsSheet

class SettingsSheet: UIViewController, UIGestureRecognizerDelegate {

    private let backdropView = UIView()
    private let containerView = UIView()
    private let grabberPill = UIView()

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .custom)

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let languageSectionHeader = UILabel()
    private let languageCard = UIView()
    private let systemLangRow = LanguageOptionRow(language: .system)
    private let spanishLangRow = LanguageOptionRow(language: .spanish)
    private let englishLangRow = LanguageOptionRow(language: .english)

    private let aboutSectionHeader = UILabel()
    private let aboutCard = UIView()
    private let appIconView = SettingsTVBadgeView()
    private let appNameLabel = UILabel()
    private let appVersionLabel = UILabel()
    private let techStackLabel = UILabel()
    private let aboutDivider = UIView()

    private let developerRow = SettingsInfoRow()
    private let githubButton = SettingsGitHubRow()

    private var containerBottomConstraint: NSLayoutConstraint?
    private var isDismissing: Bool = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupGestureRecognizers()
        setupNotifications()
        applyTheme()
        applyLocalization()
        updateSelectedLanguage()
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

    // MARK: - Notifications

    private func setupNotifications() {
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
    }

    @objc private func handleLanguageChanged() {
        applyLocalization()
        updateSelectedLanguage()
    }

    // MARK: - Setup Views & Auto Layout

    private func setupViews() {
        view.backgroundColor = .clear

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = .clear
        view.addSubview(backdropView)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 28.0
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        view.addSubview(containerView)

        grabberPill.translatesAutoresizingMaskIntoConstraints = false
        grabberPill.layer.cornerRadius = 2.5
        containerView.addSubview(grabberPill)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        containerView.addSubview(titleLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.layer.cornerRadius = 15.0
        closeButton.layer.borderWidth = 1.0
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        containerView.addSubview(closeButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        containerView.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        languageSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        languageSectionHeader.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        contentView.addSubview(languageSectionHeader)

        languageCard.translatesAutoresizingMaskIntoConstraints = false
        languageCard.layer.cornerRadius = 16.0
        languageCard.layer.borderWidth = 1.0
        contentView.addSubview(languageCard)

        systemLangRow.translatesAutoresizingMaskIntoConstraints = false
        systemLangRow.addTarget(self, action: #selector(didSelectSystemLang), for: .touchUpInside)
        languageCard.addSubview(systemLangRow)

        spanishLangRow.translatesAutoresizingMaskIntoConstraints = false
        spanishLangRow.addTarget(self, action: #selector(didSelectSpanishLang), for: .touchUpInside)
        languageCard.addSubview(spanishLangRow)

        englishLangRow.translatesAutoresizingMaskIntoConstraints = false
        englishLangRow.addTarget(self, action: #selector(didSelectEnglishLang), for: .touchUpInside)
        languageCard.addSubview(englishLangRow)

        aboutSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        aboutSectionHeader.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        contentView.addSubview(aboutSectionHeader)

        aboutCard.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.layer.cornerRadius = 16.0
        aboutCard.layer.borderWidth = 1.0
        contentView.addSubview(aboutCard)

        appIconView.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(appIconView)

        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        appNameLabel.textAlignment = .center
        aboutCard.addSubview(appNameLabel)

        appVersionLabel.translatesAutoresizingMaskIntoConstraints = false
        appVersionLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        appVersionLabel.textAlignment = .center
        aboutCard.addSubview(appVersionLabel)

        techStackLabel.translatesAutoresizingMaskIntoConstraints = false
        techStackLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        techStackLabel.textAlignment = .center
        aboutCard.addSubview(techStackLabel)

        aboutDivider.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(aboutDivider)

        developerRow.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(developerRow)

        githubButton.translatesAutoresizingMaskIntoConstraints = false
        githubButton.addTarget(self, action: #selector(didTapGitHub), for: .touchUpInside)
        aboutCard.addSubview(githubButton)

        let screenHeight = UIScreen.main.bounds.height
        let maxHeight = min(screenHeight * 0.86, 620.0)

        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 650)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint!,
            containerView.heightAnchor.constraint(equalToConstant: maxHeight),

            grabberPill.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            grabberPill.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            grabberPill.widthAnchor.constraint(equalToConstant: 40),
            grabberPill.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: grabberPill.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            languageSectionHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            languageSectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            languageSectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            languageCard.topAnchor.constraint(equalTo: languageSectionHeader.bottomAnchor, constant: 8),
            languageCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            languageCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            systemLangRow.topAnchor.constraint(equalTo: languageCard.topAnchor),
            systemLangRow.leadingAnchor.constraint(equalTo: languageCard.leadingAnchor),
            systemLangRow.trailingAnchor.constraint(equalTo: languageCard.trailingAnchor),
            systemLangRow.heightAnchor.constraint(equalToConstant: 46),

            spanishLangRow.topAnchor.constraint(equalTo: systemLangRow.bottomAnchor),
            spanishLangRow.leadingAnchor.constraint(equalTo: languageCard.leadingAnchor),
            spanishLangRow.trailingAnchor.constraint(equalTo: languageCard.trailingAnchor),
            spanishLangRow.heightAnchor.constraint(equalToConstant: 46),

            englishLangRow.topAnchor.constraint(equalTo: spanishLangRow.bottomAnchor),
            englishLangRow.leadingAnchor.constraint(equalTo: languageCard.leadingAnchor),
            englishLangRow.trailingAnchor.constraint(equalTo: languageCard.trailingAnchor),
            englishLangRow.heightAnchor.constraint(equalToConstant: 46),
            englishLangRow.bottomAnchor.constraint(equalTo: languageCard.bottomAnchor),

            aboutSectionHeader.topAnchor.constraint(equalTo: languageCard.bottomAnchor, constant: 20),
            aboutSectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            aboutSectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            aboutCard.topAnchor.constraint(equalTo: aboutSectionHeader.bottomAnchor, constant: 8),
            aboutCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            aboutCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            aboutCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            appIconView.topAnchor.constraint(equalTo: aboutCard.topAnchor, constant: 16),
            appIconView.centerXAnchor.constraint(equalTo: aboutCard.centerXAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 44),
            appIconView.heightAnchor.constraint(equalToConstant: 44),

            appNameLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 8),
            appNameLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 14),
            appNameLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -14),

            appVersionLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 4),
            appVersionLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 14),
            appVersionLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -14),

            techStackLabel.topAnchor.constraint(equalTo: appVersionLabel.bottomAnchor, constant: 3),
            techStackLabel.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 14),
            techStackLabel.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -14),

            aboutDivider.topAnchor.constraint(equalTo: techStackLabel.bottomAnchor, constant: 14),
            aboutDivider.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 14),
            aboutDivider.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -14),
            aboutDivider.heightAnchor.constraint(equalToConstant: 1.0),

            developerRow.topAnchor.constraint(equalTo: aboutDivider.bottomAnchor, constant: 8),
            developerRow.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor),
            developerRow.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor),
            developerRow.heightAnchor.constraint(equalToConstant: 44),

            githubButton.topAnchor.constraint(equalTo: developerRow.bottomAnchor),
            githubButton.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor),
            githubButton.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor),
            githubButton.heightAnchor.constraint(equalToConstant: 54),
            githubButton.bottomAnchor.constraint(equalTo: aboutCard.bottomAnchor, constant: -6)
        ])
    }

    // MARK: - Gesture Recognizers & Pan Dismiss

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

    // MARK: - Presentation & Dismissal

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

    // MARK: - Language Actions

    @objc private func didSelectSystemLang() {
        HapticManager.playSelection()
        LocalizationManager.shared.setLanguage(.system)
    }

    @objc private func didSelectSpanishLang() {
        HapticManager.playSelection()
        LocalizationManager.shared.setLanguage(.spanish)
    }

    @objc private func didSelectEnglishLang() {
        HapticManager.playSelection()
        LocalizationManager.shared.setLanguage(.english)
    }

    private func updateSelectedLanguage() {
        let current = LocalizationManager.shared.currentLanguage
        systemLangRow.setSelected(current == .system)
        spanishLangRow.setSelected(current == .spanish)
        englishLangRow.setSelected(current == .english)
    }

    // MARK: - GitHub Action

    @objc private func didTapGitHub() {
        HapticManager.playTactileClick()
        guard let url = URL(string: AppConstants.Links.gitHubRepository) else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }

    // MARK: - Theme & Localization

    private func applyTheme() {
        containerView.backgroundColor = Theme.Colors.sheetBackground
        containerView.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        containerView.layer.borderWidth = 1.0

        grabberPill.backgroundColor = Theme.Colors.sheetGrabber

        titleLabel.textColor = Theme.Colors.textPrimary

        closeButton.backgroundColor = Theme.Colors.sheetCloseButtonBackground
        closeButton.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor
        closeButton.setTitleColor(Theme.Colors.textPrimary, for: .normal)

        languageSectionHeader.textColor = Theme.Colors.textSecondary
        aboutSectionHeader.textColor = Theme.Colors.textSecondary

        languageCard.backgroundColor = Theme.Colors.sheetCardBackground
        languageCard.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor

        aboutCard.backgroundColor = Theme.Colors.sheetCardBackground
        aboutCard.layer.borderColor = Theme.Colors.sheetCardBorder.cgColor

        appNameLabel.textColor = Theme.Colors.textPrimary
        appVersionLabel.textColor = Theme.Colors.accent
        techStackLabel.textColor = Theme.Colors.textSecondary
        aboutDivider.backgroundColor = Theme.Colors.sheetCardBorder

        systemLangRow.applyTheme()
        spanishLangRow.applyTheme()
        englishLangRow.applyTheme()

        appIconView.applyTheme()
        developerRow.applyTheme()
        githubButton.applyTheme()
    }

    private func applyLocalization() {
        titleLabel.text = L10n.Settings.title
        languageSectionHeader.text = L10n.Settings.languageHeader
        aboutSectionHeader.text = L10n.Settings.aboutHeader

        systemLangRow.updateTitle(L10n.Settings.languageSystem)
        spanishLangRow.updateTitle(L10n.Settings.languageEs)
        englishLangRow.updateTitle(L10n.Settings.languageEn)

        appNameLabel.text = L10n.Settings.appName

        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        appVersionLabel.text = L10n.Settings.version(short: shortVersion, build: buildVersion)
        techStackLabel.text = L10n.Settings.techStack

        developerRow.update(title: L10n.Settings.developerTitle, value: L10n.Settings.developerName)
        githubButton.update(title: L10n.Settings.githubRepoTitle, subtitle: L10n.Settings.githubRepoSubtitle)
    }
}

// MARK: - LanguageOptionRow

private class LanguageOptionRow: UIControl {

    let language: AppLanguage
    private let flagLabel = UILabel()
    private let titleLabel = UILabel()
    private let checkmarkView = CircularCheckmarkView()
    private let divider = UIView()

    init(language: AppLanguage) {
        self.language = language
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        flagLabel.translatesAutoresizingMaskIntoConstraints = false
        flagLabel.font = UIFont.systemFont(ofSize: 18)
        addSubview(flagLabel)

        switch language {
        case .system: flagLabel.text = "🌐"
        case .spanish: flagLabel.text = "🇪🇸"
        case .english: flagLabel.text = "🇺🇸"
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        addSubview(titleLabel)

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.isHidden = true
        addSubview(checkmarkView)

        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)

        NSLayoutConstraint.activate([
            flagLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            flagLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            flagLabel.widthAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: flagLabel.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),

            checkmarkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 22),
            checkmarkView.heightAnchor.constraint(equalToConstant: 22),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    func updateTitle(_ title: String) {
        titleLabel.text = title
    }

    func setSelected(_ selected: Bool) {
        checkmarkView.isHidden = !selected
        titleLabel.font = selected ? UIFont.systemFont(ofSize: 14, weight: .bold) : UIFont.systemFont(ofSize: 14, weight: .medium)
    }

    func applyTheme() {
        titleLabel.textColor = Theme.Colors.textPrimary
        divider.backgroundColor = Theme.Colors.sheetCardBorder
    }
}

// MARK: - SettingsInfoRow

private class SettingsInfoRow: UIView {

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        addSubview(titleLabel)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textAlignment = .right
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10)
        ])
    }

    func update(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }

    func applyTheme() {
        titleLabel.textColor = Theme.Colors.textSecondary
        valueLabel.textColor = Theme.Colors.textPrimary
    }
}

// MARK: - SettingsGitHubRow

private class SettingsGitHubRow: UIControl {

    private let iconView = GitHubIconVectorView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronView = ChevronRightView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.isUserInteractionEnabled = false
        addSubview(subtitleLabel)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.isUserInteractionEnabled = false
        addSubview(chevronView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -8),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),
            chevronView.heightAnchor.constraint(equalToConstant: 14)
        ])

        addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
        addTarget(self, action: #selector(handleTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func handleTouchDown() {
        alpha = 0.6
    }

    @objc private func handleTouchUp() {
        alpha = 1.0
    }

    func update(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    func applyTheme() {
        titleLabel.textColor = Theme.Colors.textPrimary
        subtitleLabel.textColor = Theme.Colors.accent
        iconView.applyTheme()
    }
}

// MARK: - GitHubIconVectorView (Vector Octocat / Code icon)

private class GitHubIconVectorView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let color = Theme.Colors.textPrimary
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)

        // Clean circular badge background
        let circleRect = rect.insetBy(dx: 1, dy: 1)
        ctx.setLineWidth(1.6)
        ctx.strokeEllipse(in: circleRect)

        // Code brackets vector </> inside
        let midX = rect.midX
        let midY = rect.midY

        // Left angle bracket <
        let leftBracket = UIBezierPath()
        leftBracket.move(to: CGPoint(x: midX - 4, y: midY - 5))
        leftBracket.addLine(to: CGPoint(x: midX - 8, y: midY))
        leftBracket.addLine(to: CGPoint(x: midX - 4, y: midY + 5))
        leftBracket.lineWidth = 1.6
        leftBracket.lineCapStyle = .round
        leftBracket.stroke()

        // Right angle bracket >
        let rightBracket = UIBezierPath()
        rightBracket.move(to: CGPoint(x: midX + 4, y: midY - 5))
        rightBracket.addLine(to: CGPoint(x: midX + 8, y: midY))
        rightBracket.addLine(to: CGPoint(x: midX + 4, y: midY + 5))
        rightBracket.lineWidth = 1.6
        rightBracket.lineCapStyle = .round
        rightBracket.stroke()

        // Slash /
        let slash = UIBezierPath()
        slash.move(to: CGPoint(x: midX + 2, y: midY - 6))
        slash.addLine(to: CGPoint(x: midX - 2, y: midY + 6))
        slash.lineWidth = 1.4
        slash.lineCapStyle = .round
        slash.stroke()
    }
}

// MARK: - SettingsTVBadgeView

private class SettingsTVBadgeView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let iconColor = Theme.Colors.accent
        ctx.setStrokeColor(iconColor.cgColor)
        ctx.setFillColor(iconColor.cgColor)
        ctx.setLineWidth(1.8)
        ctx.setLineCap(.round)

        // TV Outer Screen (22 x 15 pt)
        let screenRect = CGRect(x: rect.midX - 11, y: rect.midY - 10, width: 22, height: 14)
        let screenPath = UIBezierPath(roundedRect: screenRect, cornerRadius: 2.5)
        screenPath.lineWidth = 1.8
        screenPath.stroke()

        // TV Stand
        let stand = UIBezierPath()
        stand.move(to: CGPoint(x: rect.midX, y: screenRect.maxY))
        stand.addLine(to: CGPoint(x: rect.midX, y: screenRect.maxY + 3.5))
        stand.move(to: CGPoint(x: rect.midX - 4.5, y: screenRect.maxY + 3.5))
        stand.addLine(to: CGPoint(x: rect.midX + 4.5, y: screenRect.maxY + 3.5))
        stand.lineWidth = 1.8
        stand.lineCapStyle = .round
        stand.stroke()

        // Small remote control pulse dot in center of screen
        ctx.fillEllipse(in: CGRect(x: rect.midX - 2.0, y: screenRect.midY - 2.0, width: 4.0, height: 4.0))
    }
}
