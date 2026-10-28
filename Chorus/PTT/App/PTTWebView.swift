import AppKit
import WebKit

/// A service's web view with "Open in Chrome Profile" and "Copy Link" in the
/// right-click menu of a link. `WebViewPool` creates this in place of a plain
/// `WKWebView` (one-line hook).
///
/// WebKit does not say which link a context menu belongs to, so a small
/// script in an isolated world reports the link under the pointer on each
/// `contextmenu` event, just before the menu opens.
@MainActor
final class PTTWebView: WKWebView {
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        PTTContextLinkTracker.shared.install(in: self.configuration.userContentController)
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

    private static let script = """
    document.addEventListener('contextmenu', function (event) {
      var target = event.target;
      var link = target && target.closest ? target.closest('a[href]') : null;
      window.webkit.messageHandlers.\(messageName).postMessage(link ? link.href : '');
    }, true);
    """

    private let controllers = NSHashTable<WKUserContentController>.weakObjects()
    private let links = NSMapTable<WKWebView, NSURL>.weakToStrongObjects()

    /// Adds the script and handler once per content controller; services that
    /// share a controller must not register the handler twice.
    func install(in controller: WKUserContentController) {
        guard !controllers.contains(controller) else { return }
        controllers.add(controller)
        controller.addUserScript(WKUserScript(
            source: Self.script, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
        controller.add(PTTWeakMessageHandler(self), contentWorld: .defaultClient, name: Self.messageName)
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
