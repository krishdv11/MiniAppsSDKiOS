
import UIKit
import WebKit

/// View controller for displaying and launching a mini app
public class MiniAppViewController: UIViewController {
    
    private let appId: String
    private let version: String
    private var webView: WKWebView!
    private let metricsReporter = MetricsReporter.shared
    private let storageManager = StorageManager.shared
    
    /// Initialize with mini app ID and version
    public init(appId: String, version: String) {
        self.appId = appId
        self.version = version
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure full screen presentation
        modalPresentationStyle = .fullScreen
        
        setupNavigationBar()
        setupWebView()
        loadMiniApp()
    }
    
    private func setupNavigationBar() {
        // Set title to app ID
        title = appId
        
        // Configure navigation bar appearance
        guard let navBar = navigationController?.navigationBar else { return }
        
        navBar.prefersLargeTitles = false
        navBar.isTranslucent = false
        
        // Set white background color
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        
        // Set title color to black
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.black
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.black
        ]
        
        // Apply appearance
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        
        // Add back button with black color
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        backButton.tintColor = .black
        navigationItem.leftBarButtonItem = backButton
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        
        // Make webView fill screen below navigation bar
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadMiniApp() {
        guard let indexPath = storageManager.indexPath(for: appId) else {
            reportLaunchFailed(message: "index.html not found")
            showError(message: "Mini app not found. Please ensure it is downloaded.")
            return
        }
        
        // Get base path for allowing read access (should be the appId folder)
        let basePath = storageManager.basePath(for: appId)
        
        // Load the HTML file
        webView.loadFileURL(
            indexPath,
            allowingReadAccessTo: basePath
        )
        
        // Report app launched
        reportAppLaunched()
    }
    
    @objc private func backTapped() {
        reportAppClosed()
        // Dismiss the modal presentation
        dismiss(animated: true)
    }
    
    private func reportAppLaunched() {
        metricsReporter.reportEvent(
            appId: appId,
            version: version,
            eventType: "AppLaunched",
            message: nil,
            metadata: nil
        )
    }
    
    private func reportLaunchFailed(message: String) {
        metricsReporter.reportEvent(
            appId: appId,
            version: version,
            eventType: "AppLaunchFailed",
            message: message,
            metadata: nil
        )
    }
    
    private func reportAppClosed() {
        metricsReporter.reportEvent(
            appId: appId,
            version: version,
            eventType: "AppClosed",
            message: nil,
            metadata: nil
        )
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate
extension MiniAppViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Navigation finished successfully - app is fully loaded
        // AppLaunched is already reported in loadMiniApp(), so we don't need to report again
        // This delegate method can be used for future enhancements if needed
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reportLaunchFailed(message: error.localizedDescription)
        showError(message: "Failed to load mini app: \(error.localizedDescription)")
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportLaunchFailed(message: error.localizedDescription)
    }
}
