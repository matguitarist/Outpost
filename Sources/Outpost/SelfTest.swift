import AppKit
import Foundation

@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        guard Store.isOverridden else {
            print("SELFTEST refused: set APP_STORE to a file in /tmp so the test never touches real data")
            finish(code: 1)
            return
        }
        Task {
            check("the store URL is in /tmp", Store.url.path.hasPrefix("/tmp/") || Store.url.path.hasPrefix("/private/tmp/"))

            model.log.post(.info, "Self-test line", source: "SelfTest")
            try? await Task.sleep(for: .milliseconds(300))
            check("the app writes a log line", model.log.entries.contains { $0.message == "Self-test line" })

            let file = (try? String(contentsOf: Store.logURL, encoding: .utf8)) ?? ""
            check("the log file has the line", file.contains("Self-test line"))
            let issue = RepositoryLinks(repository: "matguitarist/Outpost").newIssue(app: "Outpost").absoluteString
            check("Help › Report a Problem opens a new GitHub issue with the version and macOS filled in",
                  issue.hasPrefix("https://github.com/matguitarist/Outpost/issues/new?body=") && issue.contains("macOS"), issue)
            // What's New: a newer version shows its bundled notes once; a fresh install and test runs show nothing.
            check("What's New compares versions number by number",
                  WhatsNew.isNewer("0.10.0", than: "0.9.2") && WhatsNew.isNewer("1.0", than: "0.9.9") && !WhatsNew.isNewer("0.9.0", than: "0.9.0")
                  && !WhatsNew.isNewer("2.4", than: "2.4.0") && !WhatsNew.isNewer("0.8.2", than: "0.9.0"))
            check("What's New stays quiet on a fresh install", !WhatsNew.isNewer("0.9.0", than: nil))
            check("What's New never shows in a test run", WhatsNew.isTestRun && WhatsNew.pending(defaults: UserDefaults(suiteName: "WhatsNew-selftest") ?? .standard) == nil)
            check("release notes read as headings, list items and paragraphs",
                  NotesBlock.parse("## New\n\n- **One**\n  more\n- Two\n\nText\non two lines") ==
                  [.heading("New"), .item(marker: "•", text: "**One** more"), .item(marker: "•", text: "Two"), .paragraph("Text on two lines")])

            // Verify settings tabs
            for tab in SettingsTab.allCases {
                model.settingsTab = tab
                check("settings tab \(tab.rawValue) sets cleanly", model.settingsTab == tab)
            }

            // Verify sidebar items
            for item in SidebarItem.allCases {
                model.sidebar = item
                check("sidebar item \(item.rawValue) sets cleanly", model.sidebar == item)
            }

            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ passed: Bool, _ detail: String = "") {
        count += 1
        if passed {
            print("PASS  \(name)")
        } else {
            failures += 1
            print("FAIL  \(name)\(detail.isEmpty ? "" : " - \(detail)")")
        }
    }

    private static func finish(code: Int32) {
        exitCode = code
        print("Self-test: \(count - failures)/\(count) passed")
        NSApp.terminate(nil)
    }
}
