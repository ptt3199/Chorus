import AppKit
import WebKit

/// A service's web view with "Open in Chrome Profile" and "Copy Link" in the
/// right-click menu of a link. `WebViewPool` creates this in place of a plain
/// `WKWebView` (one-line hook).
///
/// WebKit does not say which link a context menu belongs to, so a small
/// script in an isolated world reports the link under the pointer on each
/// `contextmenu` event, just before the menu opens.
///
/// Chorus clears every user script when it applies a dark theme
/// (`WebViewPool.applyInjectionLive`), which drops this one too, so the view
/// puts it back before each load and on each right-click.
@MainActor
final class PTTWebView: WKWebView {
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        PTTContextLinkTracker.shared.ensureInstalled(in: self)
    }

    @discardableResult
    override func load(_ request: URLRequest) -> WKNavigation? {
        PTTContextLinkTracker.shared.ensureInstalled(in: self)
        return super.load(request)
    }

    @discardableResult
    override func reload() -> WKNavigation? {
        PTTContextLinkTracker.shared.ensureInstalled(in: self)
        return super.reload()
    }

    override func rightMouseDown(with event: NSEvent) {
        PTTContextLinkTracker.shared.ensureInstalled(in: self)
        super.rightMouseDown(with: event)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        let linkItemIDs: Set<String> = ["WKMenuItemIdentifierCopyLink", "WKMenuItemIdentifierOpenLink"]
        guard menu.items.contains(where: { linkItemIDs.contains($0.identifier?.rawValue ?? "") }),
              let url = PTTContextLinkTracker.shared.link(for: self),
              PTTLinkHook.isWeb(url)
        else { return }
        let sourceServiceID = (navigationDelegate as? WebViewCoordinator)?.instanceID
        let items = PTTLinkMenus.contextItems(for: url, from: sourceServiceID)
        // Ours replaces WebKit's "Copy Link", which would copy the redirect.
        if let index = menu.items.firstIndex(where: { $0.identifier?.rawValue == "WKMenuItemIdentifierCopyLink" }) {
            menu.removeItem(at: index)
            menu.insertItem(items[1], at: index)
            menu.insertItem(items[0], at: index)
        } else {
            menu.addItem(.separator())
            for item in items { menu.addItem(item) }
        }
    }
}

/// Remembers, per web view, the link the last `contextmenu` event was on.
@MainActor
final class PTTContextLinkTracker: NSObject, WKScriptMessageHandler {
    static let shared = PTTContextLinkTracker()
    static let messageName = "pttContextLink"

    /// Guarded by a flag so running it again on a live page adds no second
    /// listener.
    private static let script = """
    (function () {
      if (window.__pttContextLink) { return; }
      window.__pttContextLink = true;
      document.addEventListener('contextmenu', function (event) {
        var target = event.target;
        var link = target && target.closest ? target.closest('a[href]') : null;
        window.webkit.messageHandlers.\(messageName).postMessage(link ? link.href : '');
      }, true);
    })();
    """

    private let controllers = NSHashTable<WKUserContentController>.weakObjects()
    private let links = NSMapTable<WKWebView, NSURL>.weakToStrongObjects()

    /// Registers the message handler once per content controller (adding it
    /// twice throws), and puts the script back whenever Chorus has cleared the
    /// user scripts, running it on the page already shown as well.
    func ensureInstalled(in webView: WKWebView) {
        let controller = webView.configuration.userContentController
        if !controllers.contains(controller) {
            controllers.add(controller)
            controller.add(PTTWeakMessageHandler(self), contentWorld: .defaultClient, name: Self.messageName)
        }
        guard !controller.userScripts.contains(where: { $0.source == Self.script }) else { return }
        controller.addUserScript(WKUserScript(
            source: Self.script, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
        if webView.url != nil {
            webView.evaluateJavaScript(Self.script, in: nil, in: .defaultClient, completionHandler: nil)
        }
    }

    func link(for webView: WKWebView) -> URL? {
        links.object(forKey: webView) as URL?
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else { return }
        if let href = message.body as? String, let url = URL(string: href), !href.isEmpty {
            links.setObject(url as NSURL, forKey: webView)
        } else {
            links.removeObject(forKey: webView)
        }
    }
}

/// Holds the tracker weakly; `WKUserContentController` retains its handlers.
@MainActor
private final class PTTWeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
