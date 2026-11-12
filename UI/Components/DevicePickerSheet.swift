import UIKit

protocol DevicePickerDelegate: AnyObject {
    func devicePickerDidSelectDevice(_ picker: DevicePickerSheet, device: DiscoveredTV)
}

class DevicePickerSheet: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: DevicePickerDelegate?

    var devices: [DiscoveredTV] = [] {
        didSet {
            tableView.reloadData()
            emptyLabel.isHidden = !devices.isEmpty
        }
    }

    private let containerView = UIView()
    private let grabberHandle = UIView()
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let emptyLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .gray)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapDimmedBackground(_:)))
        view.addGestureRecognizer(tap)

        setupLayout()
    }

    private func setupLayout() {
        containerView.backgroundColor = Theme.Colors.surface
        containerView.layer.cornerRadius = 24.0
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        grabberHandle.backgroundColor = Theme.Colors.border
        grabberHandle.layer.cornerRadius = 2.5
        grabberHandle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(grabberHandle)

        titleLabel.text = "Televisores Detectados"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = Theme.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        containerView.addSubview(spinner)

        tableView.backgroundColor = .clear
        tableView.separatorColor = Theme.Colors.divider
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(tableView)

        emptyLabel.text = "Buscando dispositivos en la red..."
        emptyLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = Theme.Colors.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 320),

            grabberHandle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            grabberHandle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            grabberHandle.widthAnchor.constraint(equalToConstant: 40),
            grabberHandle.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: grabberHandle.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),

            spinner.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),

            emptyLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }

    @objc private func didTapDimmedBackground(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        if !containerView.frame.contains(location) {
            dismiss(animated: true)
        }
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let tv = devices[indexPath.row]
        
        cell.backgroundColor = .clear
        cell.textLabel?.text = "📺  \(tv.name)"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cell.textLabel?.textColor = Theme.Colors.textPrimary
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selected = devices[indexPath.row]
        HapticManager.playTactileClick()
        dismiss(animated: true) {
            self.delegate?.devicePickerDidSelectDevice(self, device: selected)
        }
    }
}
