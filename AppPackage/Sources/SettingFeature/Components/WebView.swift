import AppTools
import WebKit
import AppModels
import NetworkingFeature
import SwiftUI

/// Each presentation starts with the native account's cookies, avoiding stale WebKit sessions after logout.
struct WebView: UIViewControllerRepresentable {
    private let url: URL
    private let loginDoneAction: (() -> Void)?

    init(url: URL, loginDoneAction: (() -> Void)? = nil) {
        self.url = url
        self.loginDoneAction = loginDoneAction
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let parent: WebView
        private var completedLogin = false

        init(parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                for cookie in cookies where Self.isAccountDomain(cookie.domain) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                guard let self, !self.completedLogin, self.parent.loginDoneAction != nil,
                      cookies.contains(where: { $0.name == "ipb_member_id" && !$0.value.isEmpty }),
                      cookies.contains(where: { $0.name == "ipb_pass_hash" && !$0.value.isEmpty })
                else { return }
                self.completedLogin = true
                self.parent.loginDoneAction?()
            }
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(["https", "http", "about"].contains(url.scheme ?? "") ? .allow : .cancel)
        }

        func webView(
            _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let scheme = navigationAction.request.url?.scheme, ["https", "http"].contains(scheme) {
                webView.load(navigationAction.request)
            }
            return nil
        }

        static func isAccountDomain(_ domain: String) -> Bool {
            let host = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return ["e-hentai.org", "exhentai.org"].contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> EmbeddedWebviewController {
        let controller = EmbeddedWebviewController(coordinator: context.coordinator)
        controller.loadUrl(url)
        return controller
    }

    func updateUIViewController(_ controller: EmbeddedWebviewController, context: Context) {}
}

@MainActor
final class EmbeddedWebviewController: UIViewController {
    private let webview: WKWebView
    private let controls = UIToolbar()
    private weak var delegate: WebView.Coordinator?

    init(coordinator: WebView.Coordinator) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let text = UserDefaults.standard.string(forKey: SXJNetworkSettings.proxyKey) ?? ""
        if let proxy = try? SXJNetworkSettings.proxyConfiguration(text) {
            configuration.websiteDataStore.proxyConfigurations = [proxy]
        }
        webview = WKWebView(frame: .zero, configuration: configuration)
        delegate = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        webview = WKWebView()
        super.init(coder: coder)
    }

    func loadUrl(_ url: URL) {
        let cookieStore = webview.configuration.websiteDataStore.httpCookieStore
        let cookies = (HTTPCookieStorage.shared.cookies ?? []).filter { WebView.Coordinator.isAccountDomain($0.domain) }
        Task { @MainActor in
            for cookie in cookies {
                await withCheckedContinuation { continuation in
                    cookieStore.setCookie(cookie) { continuation.resume() }
                }
            }
            webview.load(URLRequest(url: url))
        }
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
        webview.navigationDelegate = delegate
        webview.uiDelegate = delegate
        webview.translatesAutoresizingMaskIntoConstraints = false
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webview)
        view.addSubview(controls)
        controls.items = [
            UIBarButtonItem(title: "后退", primaryAction: UIAction { [weak self] _ in self?.webview.goBack() }),
            .flexibleSpace(),
            UIBarButtonItem(title: "前进", primaryAction: UIAction { [weak self] _ in self?.webview.goForward() }),
            .flexibleSpace(),
            UIBarButtonItem(title: "刷新", primaryAction: UIAction { [weak self] _ in self?.webview.reload() })
        ]
        NSLayoutConstraint.activate([
            webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webview.bottomAnchor.constraint(equalTo: controls.topAnchor),
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
