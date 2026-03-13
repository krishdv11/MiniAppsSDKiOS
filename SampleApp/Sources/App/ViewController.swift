import MiniAppsSDK
import UIKit

final class ViewController: UIViewController {
    private let baseURLField = UITextField()
    private let appIdField = UITextField()
    private let loadButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let bannerContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MiniApps SDK Sample"
        view.backgroundColor = .systemBackground
        setupUI()
        prefillDefaults()
    }

    private func setupUI() {
        baseURLField.placeholder = "Base URL (e.g. https://api.example.com)"
        appIdField.placeholder = "App ID"
        [baseURLField, appIdField].forEach {
            $0.borderStyle = .roundedRect
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        statusLabel.text = "Enter base URL and app ID, then tap Load."
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        loadButton.setTitle("Initialize + Fetch Banners", for: .normal)
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        loadButton.addTarget(self, action: #selector(loadTapped), for: .touchUpInside)

        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.backgroundColor = .secondarySystemBackground
        bannerContainer.layer.cornerRadius = 12

        view.addSubview(baseURLField)
        view.addSubview(appIdField)
        view.addSubview(loadButton)
        view.addSubview(statusLabel)
        view.addSubview(bannerContainer)

        NSLayoutConstraint.activate([
            baseURLField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            baseURLField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            baseURLField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            appIdField.topAnchor.constraint(equalTo: baseURLField.bottomAnchor, constant: 12),
            appIdField.leadingAnchor.constraint(equalTo: baseURLField.leadingAnchor),
            appIdField.trailingAnchor.constraint(equalTo: baseURLField.trailingAnchor),

            loadButton.topAnchor.constraint(equalTo: appIdField.bottomAnchor, constant: 14),
            loadButton.leadingAnchor.constraint(equalTo: appIdField.leadingAnchor),

            statusLabel.topAnchor.constraint(equalTo: loadButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: baseURLField.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: baseURLField.trailingAnchor),

            bannerContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            bannerContainer.leadingAnchor.constraint(equalTo: baseURLField.leadingAnchor),
            bannerContainer.trailingAnchor.constraint(equalTo: baseURLField.trailingAnchor),
            bannerContainer.heightAnchor.constraint(equalToConstant: 220)
        ])
    }

    private func prefillDefaults() {
        baseURLField.text = "https://csdpdev-api.d21.co.in"
        appIdField.text = "sample-super-app"
    }

    @objc
    private func loadTapped() {
        guard let baseURL = baseURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !baseURL.isEmpty,
              let appId = appIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !appId.isEmpty else {
            setStatus("Base URL and App ID are required.", isError: true)
            return
        }

        clearBannerContainer()
        setStatus("Initializing SDK...", isError: false)

        MiniAppsSDK.shared.initialize(baseURL: baseURL, appId: appId)
        MiniAppsSDK.shared.fetchMiniAppsWithView(width: Int(view.bounds.width), height: 220) { [weak self] bannerView, error in
            guard let self = self else { return }
            if let error = error {
                self.setStatus("Fetch failed: \(error.localizedDescription)", isError: true)
                return
            }

            guard let bannerView else {
                self.setStatus("Fetch returned no view.", isError: true)
                return
            }

            self.embedBannerView(bannerView)
            self.setStatus("Loaded successfully. Tap a banner to launch mini app.", isError: false)
        }
    }

    private func embedBannerView(_ bannerView: UIView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor)
        ])
    }

    private func clearBannerContainer() {
        bannerContainer.subviews.forEach { $0.removeFromSuperview() }
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabel
    }
}
