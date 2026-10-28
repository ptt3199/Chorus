# Hooks into upstream files

Every change Chorus PTT makes to a file it does not own. Each line carries a
`// PTT:` comment, so `git grep -n "PTT:"` lists them all. When a rebase onto
upstream conflicts, re-apply the line below in the new code and keep it one line.

## App identity (commit "chore: split Chorus PTT into its own app")

| File | Where | Purpose |
|---|---|---|
| `project.yml` | `options.bundleIdPrefix`, `targets.Chorus.settings`, `configs`, `ChorusTests` | Bundle ids `com.ptt3199.Chorus[.debug]`, `com.ptt3199.ChorusTests`; product name "Chorus PTT"; module name stays `Chorus`; Release signs ad-hoc (`CODE_SIGN_IDENTITY: "-"`, no `DEVELOPMENT_TEAM`); Sparkle package and dependency removed; `PTT/**/*.md` excluded from the bundle. |
| `Chorus/Info.plist` | top of the dict | `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`, `SUScheduledCheckInterval` removed. |
| `Chorus/App/StoreRelocation.swift` | `folderName` | Store folder `Chorus PTT` (`PTTAppIdentity.storeFolder`). |
| `Chorus/App/StoreRelocation.swift` | `resolveStoreURL()` | `legacy` points at the fork's own store, so the original Chorus store (`Application Support/default.store`) is never moved in. |
| `Chorus/App/AppState.swift` | `init()`, `#if DEBUG` store dir | Debug store folder `Chorus PTT-debug`. |
| `Chorus/Views/Tips/FeatureTips.swift` | `configure()`, `#if DEBUG` | TipKit folder `Chorus PTT-debug` (Release follows `StoreRelocation.folderName`). |
| `.github/workflows/test.yml` | `on.push.branches` | Also runs on `ptt`. |
| `.github/workflows/pages.yml` | — | Deleted (appcast deploy). |
| `.github/workflows/ptt-build.yml` | — | New: Release build, ad hoc, uploaded as an artifact. |
| `Chorus.xcodeproj/xcshareddata/.../Package.resolved` | — | Deleted (Sparkle pin). |

## Chrome profile links

| File | Function | Purpose |
|---|---|---|
| `Chorus/Views/WebView/WebViewCoordinator.swift` | `openExternally(_:from:)` | Adds the defaulted `from sourceServiceID` parameter. |
| `Chorus/Views/WebView/WebViewCoordinator.swift` | `openExternally(_:from:)` | `PTTLinkHook.open` routes web links to a Chrome profile before `NSWorkspace.open`. |
| `Chorus/Views/WebView/WebViewCoordinator.swift` | `webView(_:decidePolicyFor:)` (navigation action), top | `PTTLinkHook.handleOptionClick`: ⌥-click on an outside link shows the profile menu. |
| `Chorus/Views/WebView/WebViewCoordinator.swift` | same, after the ⌥-click hook | `PTTLinkHook.handlePopupNavigation`: a link inside a service popup (Google Chat's named Docs window) opens in Chrome when a profile applies. |
| `Chorus/Views/WebView/WebViewCoordinator.swift` | same, step 3 (⌘-click) | Passes `instanceID` to `openExternally`. |
| `Chorus/Views/WebView/WebViewCoordinator.swift` | `webView(_:createWebViewWith:...)`, before the tab decision | `PTTLinkHook.handleScriptedWindow`: `window.open` to another site opens in Chrome when a profile applies. |
| `Chorus/App/AppState.swift` | `handleExternalLink(_:from:)` | Passes `sourceServiceID` to `openExternally`. |
| `Chorus/App/AppState.swift` | `setupExternalLinkRouting()` | Gives `PTTLinkService` service names for the link log. |
| `Chorus/Views/MainWindow/WebToolbarView.swift` | `openInDefaultBrowser()` | Passes the page's service to `openExternally`. |
| `Chorus/Views/MainWindow/UnifiedRailView.swift` | `openInDefaultBrowser(_:)` | Passes `service.id` to `openExternally`. |
| `Chorus/Views/WebView/WebViewPool.swift` | two `WKWebView(frame:configuration:)` calls | Creates `PTTWebView`, which adds the right-click "Open in Chrome Profile" and "Copy Link" items. |
| `Chorus/Views/AddService/EditServiceSheet.swift` | `webSettings`, after "Open outside links in" | `PTTServiceProfilePicker(serviceID:)`. |
| `Chorus/Views/Settings/SettingsView.swift` | `settingsTabs` | `PTTLinkSettingsTab()` (brings its own `tabItem`). |
