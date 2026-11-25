import Foundation
import Testing
@testable import OutpostKit

@Suite struct SSHClientTests {
    @Test func buildsArgumentsWithIdentityFile() {
        let client = SSHClient(target: "root@192.168.40.210", identityFile: "~/.ssh/id_ed25519_homeserver", port: 22)
        let args = client.sshArguments("uname -a")
        #expect(args.contains("-i"))
        #expect(args.contains("IdentitiesOnly=yes"))
        #expect(args.contains("root@192.168.40.210"))
        #expect(args.contains("uname -a"))
    }

    @Test func buildsArgumentsWithoutIdentityFile() {
        let client = SSHClient(target: "root@192.168.40.210")
        let args = client.sshArguments()
        #expect(!args.contains("-i"))
        #expect(args.contains("root@192.168.40.210"))
    }

    /// Runs the real ssh against a closed local port: the master it tries to start in the background
    /// fails, and its own words come back in the error.
    @Test func refusedConnectionReportsSSHsMessage() async throws {
        let client = SSHClient(target: "nobody@127.0.0.1", port: 1)
        do {
            _ = try await client.runRemote("true")
            Issue.record("ssh to a closed port succeeded")
        } catch let error as SSHError {
            guard case .command(let status, let message) = error else { Issue.record("\(error)"); return }
            #expect(status == 255)
            #expect(message.contains("refused"))
            #expect(error.localizedDescription.contains("refused"))
        }
    }
}
