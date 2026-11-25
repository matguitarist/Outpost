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
