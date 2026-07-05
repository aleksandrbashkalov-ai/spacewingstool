import Foundation
import AppKit

public struct BrowserPage: Sendable, Equatable {
    public var url: String
    public var title: String
    public var textContent: String?
    public var browser: String

    public init(url: String, title: String, textContent: String? = nil, browser: String) {
        self.url = url
        self.title = title
        self.textContent = textContent
        self.browser = browser
    }
}

public enum BrowserType: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case safariWebKit = "com.apple.WebKit.WebContent"
    case chrome = "com.google.Chrome"
    case brave = "com.brave.Browser"
    case edge = "com.microsoft.Edge"
    case firefox = "org.mozilla.firefox"
    case arc = "company.thebrowser.Browser"
    case orion = "com.kagi.kagimacOS"

    public var displayName: String {
        switch self {
        case .safari, .safariWebKit: return "Safari"
        case .chrome: return "Chrome"
        case .brave: return "Brave"
        case .edge: return "Edge"
        case .firefox: return "Firefox"
        case .arc: return "Arc"
        case .orion: return "Orion"
        }
    }

    public static func from(bundleID: String) -> BrowserType? {
        BrowserType(rawValue: bundleID) ?? BrowserType.allCases.first { bundleID.hasPrefix($0.rawValue) }
    }

    public static var readingRelevant: [BrowserType] {
        [.safari, .chrome, .brave, .edge, .firefox, .arc, .orion]
    }
}

public struct BrowserExtractor: Sendable {

    public func detectBrowser(from bundleID: String) -> BrowserType? {
        BrowserType.from(bundleID: bundleID)
    }

    public func extractFrontPage(for bundleID: String) async -> BrowserPage? {
        guard let browser = BrowserType.from(bundleID: bundleID) else { return nil }
        return await extractPage(browser: browser)
    }

    public func extractPage(browser: BrowserType) async -> BrowserPage? {
        switch browser {
        case .safari, .safariWebKit:
            return await extractSafari()
        case .chrome:
            return await extractChrome()
        case .brave:
            return await extractChromium(browser: "Brave", bundleID: "com.brave.Browser")
        case .edge:
            return await extractChromium(browser: "Microsoft Edge", bundleID: "com.microsoft.Edge")
        case .arc:
            return await extractChromium(browser: "Arc", bundleID: "company.thebrowser.Browser")
        case .orion:
            return await extractChromium(browser: "Orion", bundleID: "com.kagi.kagimacOS")
        case .firefox:
            return await extractFirefox()
        }
    }

    // MARK: - Safari

    private func extractSafari() async -> BrowserPage? {
        let urlScript = """
        tell application "Safari"
            set currentURL to URL of current tab of front window
            set currentTitle to name of current tab of front window
            return currentURL & "|||" & currentTitle
        end tell
        """

        guard let result = await runAppleScript(urlScript),
              let (url, title) = parseDelimited(result, delimiter: "|||") else { return nil }

        let text = await extractSafariText()
        return BrowserPage(url: url, title: title, textContent: text, browser: "Safari")
    }

    private func extractSafariText() async -> String? {
        let textScript = """
        tell application "Safari"
            set pageText to do JavaScript "document.body.innerText" in current tab of front window
            return pageText
        end tell
        """
        let result = await runAppleScript(textScript)
        return result?.isEmpty == false ? result : nil
    }

    // MARK: - Chrome

    private func extractChrome() async -> BrowserPage? {
        let urlScript = """
        tell application "Google Chrome"
            set currentURL to URL of active tab of front window
            set currentTitle to title of active tab of front window
            return currentURL & "|||" & currentTitle
        end tell
        """

        guard let result = await runAppleScript(urlScript),
              let (url, title) = parseDelimited(result, delimiter: "|||") else { return nil }

        let text = await extractChromeText()
        return BrowserPage(url: url, title: title, textContent: text, browser: "Chrome")
    }

    private func extractChromeText() async -> String? {
        let textScript = """
        tell application "Google Chrome"
            set pageText to execute active tab of front window javascript "document.body.innerText"
            return pageText
        end tell
        """

        let result = await runAppleScript(textScript)
        return result?.isEmpty == false ? result : nil
    }

    // MARK: - Chromium-based (Brave, Edge, Arc, Orion)

    private func extractChromium(browser: String, bundleID: String) async -> BrowserPage? {
        let urlScript = """
        tell application "\(browser)"
            set currentURL to URL of active tab of front window
            set currentTitle to title of active tab of front window
            return currentURL & "|||" & currentTitle
        end tell
        """

        guard let result = await runAppleScript(urlScript),
              let (url, title) = parseDelimited(result, delimiter: "|||") else {
            return nil
        }

        let text = await extractChromiumText(browser: browser)
        return BrowserPage(url: url, title: title, textContent: text, browser: browser)
    }

    private func extractChromiumText(browser: String) async -> String? {
        let textScript = """
        tell application "\(browser)"
            set pageText to execute active tab of front window javascript "document.body.innerText"
            return pageText
        end tell
        """

        let result = await runAppleScript(textScript)
        return result?.isEmpty == false ? result : nil
    }

    // MARK: - Firefox

    private func extractFirefox() async -> BrowserPage? {
        let savedClipboard = NSPasteboard.general.string(forType: .string)

        let urlScript = """
        tell application "System Events"
            set firefox to first application process whose bundle identifier is "org.mozilla.firefox"
            set frontmost to true
        end tell
        tell application "Firefox"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            keystroke "l" using command down
            delay 0.1
            keystroke "c" using command down
            delay 0.1
            set currentURL to the clipboard
            keystroke tab using command down
            delay 0.1
            keystroke "c" using command down
            delay 0.1
            set currentTitle to the clipboard
            return currentURL & "|||" & currentTitle
        end tell
        """

        defer {
            if let saved = savedClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(saved, forType: .string)
            }
        }

        guard let result = await runAppleScript(urlScript),
              let (url, title) = parseDelimited(result, delimiter: "|||") else { return nil }

        return BrowserPage(url: url, title: title, browser: "Firefox")
    }

    // MARK: - Helpers

    private func runAppleScript(_ source: String) async -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return output.stringValue
    }

    private func parseDelimited(_ string: String, delimiter: String) -> (String, String)? {
        let parts = string.components(separatedBy: delimiter)
        guard parts.count >= 2 else { return nil }
        return (parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
                parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

extension BrowserPage {
    public var isReadingCandidate: Bool {
        let readingDomains = ["wikipedia.org", "medium.com", "docs.", "news.", "blog.",
                              "article", "guide", "tutorial", "documentation", "wiki"]
        let urlLower = url.lowercased()
        return readingDomains.contains { urlLower.contains($0) }
            || !(urlLower.contains("youtube.com") || urlLower.contains("netflix.com"))
    }
}
