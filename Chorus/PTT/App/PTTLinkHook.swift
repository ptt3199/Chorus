import AppKit
import Foundation
import WebKit

/// The entry points Chorus's own files call. Each call site is one line
/// marked `// PTT:` (see `Chorus/PTT/HOOKS.md`); everything else lives here.
enum PTTLinkHook {
    /// From `WebViewCoordinator.openExternally`: opens a web link in a Chrome
    /// profile when a rule or the source service picks one. Returns false to
    /// let Chorus open it as before. Runs only on the main thread, which is
    /// where every caller is; anywhere else it leaves the link alone.
    nonisolated static func open(_ url: URL, from sourceServiceID: UUID?) -> Bool {
        guard isWeb(url), Thread.isMainThread else { return false }
        return MainActor.assumeIsolated {
            PTTLinkService.shared.route(url, from: sourceServiceID)
        }
    }

    /// From `decidePolicyFor`: an ⌥-click on a link that leaves the service
    /// shows a menu of Chrome profiles instead of WebKit's download.
    @MainActor
    static func handleOptionClick(_ action: WKNavigationAction, in webView: WKWebView, from sourceServiceID: UUID?) -> Bool {
        guard action.navigationType == .linkActivated,
              action.modifierFlags.contains(.option),
              let url = action.request.url, isWeb(url),
              let currentHost = webView.url?.host,
              WebViewCoordinator.routesClickedLinkOut(url, currentHost: currentHost)
        else { return false }
        // Shown after WebKit has its answer, so the menu's own event loop does
        // not hold the navigation callback open.
        Task { @MainActor in
            PTTLinkMenus.showProfileMenu(for: url, in: webView, from: sourceServiceID)
        }
        return true
    }

    /// From `createWebViewWith`: a page's `window.open` to another site opens
    /// in Chrome when a rule or the service picks a profile that exists.
    /// Sign-in popups, sized windows, the service's own pages and links
    /// another Chorus service owns keep Chorus's behaviour.
    @MainActor
    static func handleScriptedWindow(
        _ action: WKNavigationAction,
        opener: WKWebView,
        openerIsPopup: Bool,
        windowFeatures: WKWindowFeatures,
        serviceOwnsURL: ((URL, UUID?) -> Bool)?,
        from sourceServiceID: UUID?
    ) -> Bool {
        let requestedSize = windowFeatures.width != nil || windowFeatures.height != nil
        guard action.navigationType != .linkActivated,
              !openerIsPopup, !requestedSize,
              let url = action.request.url, isWeb(url),
              !(serviceOwnsURL?(url, sourceServiceID) ?? false),
              let targetHost = url.host,
              let openerHost = opener.url?.host,
              !WebViewCoordinator.belongsToService(targetHost, serviceHost: openerHost),
              !WebViewCoordinator.isAuthHost(targetHost),
              !WebViewCoordinator.looksLikeSignIn(url)
        else { return false }
        return PTTLinkService.shared.route(url, from: sourceServiceID, onlyChrome: true)
    }

    nonisolated static func isWeb(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}

/// The menus that let the user pick a profile for one link.
@MainActor
enum PTTLinkMenus {
    /// The ⌥-click menu: one item per profile, then "Always Open <domain> In"
    /// with a submenu of profiles, then the default browser.
    static func showProfileMenu(for url: URL, in view: NSView, from sourceServiceID: UUID?) {
        let service = PTTLinkService.shared
        service.reloadProfiles()
        let menu = NSMenu()
        let host = PTTURLRewriting.unwrapRedirect(url).host ?? ""
        let domain = host.lowercased().hasPrefix("www.") ? String(host.dropFirst(4)) : host

        if service.profiles.isEmpty {
            let empty = NSMenuItem(title: "No Chrome profiles found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for profile in service.profiles {
            menu.addItem(ClosureMenuItem(title: "Open in \(title(for: profile))") {
                service.open(url, inProfileNamed: profile.name, from: sourceServiceID)
            })
        }
        if !service.profiles.isEmpty, !domain.isEmpty {
            menu.addItem(.separator())
            let always = NSMenuItem(title: "Always Open \(domain) In", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for profile in service.profiles {
                submenu.addItem(ClosureMenuItem(title: title(for: profile)) {
                    service.alwaysOpen(url, inProfileNamed: profile.name, from: sourceServiceID)
                })
            }
            always.submenu = submenu
            menu.addItem(always)
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Open in Default Browser") {
            NSWorkspace.shared.open(PTTURLRewriting.unwrapRedirect(url))
        })

        let point = view.window.map { view.convert($0.mouseLocationOutsideOfEventStream, from: nil) } ?? .zero
        _ = menu.popUp(positioning: nil, at: point, in: view)
    }

    /// Items added to a web view's right-click menu on a link: a submenu of
    /// profiles and "Copy Link", which copies the link without Google's
    /// redirect wrapper.
    static func contextItems(for url: URL, from sourceServiceID: UUID?) -> [NSMenuItem] {
        let service = PTTLinkService.shared
        service.reloadProfiles()
        let open = NSMenuItem(title: "Open in Chrome Profile", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if service.profiles.isEmpty {
            let empty = NSMenuItem(title: "No Chrome profiles found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        for profile in service.profiles {
            submenu.addItem(ClosureMenuItem(title: title(for: profile)) {
                service.open(url, inProfileNamed: profile.name, from: sourceServiceID)
            })
        }
        open.submenu = submenu
        let copy = ClosureMenuItem(title: "Copy Link") {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(PTTURLRewriting.unwrapRedirect(url).absoluteString, forType: .string)
        }
        return [open, copy]
    }

    static func title(for profile: PTTChromeProfile) -> String {
        guard let email = profile.email else { return profile.name }
        return "\(profile.name) (\(email))"
    }
}

/// A menu item that runs a closure, so menus need no target object.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run() {
        handler()
    }
}

extension PTTLinkHook {
    /// The service a web view belongs to, for callers that hold only the view.
    @MainActor
    static func serviceID(of webView: WKWebView?) -> UUID? {
        (webView?.navigationDelegate as? WebViewCoordinator)?.instanceID
    }
}

extension PTTLinkHook {
    /// From `decidePolicyFor`: a navigation inside one of the service's popup
    /// windows that leaves the service opens in Chrome when a rule or the
    /// service picks a profile that exists. An empty popup is then closed.
    @MainActor
    static func handlePopupNavigation(
        _ action: WKNavigationAction,
        in popup: WKWebView,
        isPopup: Bool,
        serviceHost: String?,
        serviceOwnsURL: ((URL, UUID?) -> Bool)?,
        from sourceServiceID: UUID?
    ) -> Bool {
        guard isPopup, let url = action.request.url, let targetHost = url.host, let serviceHost else { return false }
        let current = popup.url
        let currentIsSignIn = current.map { url in
            WebViewCoordinator.looksLikeSignIn(url) || url.host.map(WebViewCoordinator.isAuthHost) == true
        } ?? false
        guard PTTPopupRouting.shouldConsider(
            isPopup: isPopup,
            isMainFrame: action.targetFrame?.isMainFrame ?? true,
            targetIsWeb: isWeb(url),
            leavesService: !WebViewCoordinator.belongsToService(targetHost, serviceHost: serviceHost),
            targetIsSignIn: WebViewCoordinator.isAuthHost(targetHost) || WebViewCoordinator.looksLikeSignIn(url),
            currentPageIsSignIn: currentIsSignIn
        ), !(serviceOwnsURL?(url, sourceServiceID) ?? false),
            PTTLinkService.shared.route(url, from: sourceServiceID, onlyChrome: true)
        else { return false }
        if PTTPopupRouting.isBlank(current) {
            let window = popup.window
            Task { @MainActor in window?.close() }
        }
        return true
    }
}
